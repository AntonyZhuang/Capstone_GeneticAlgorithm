// Genetic Algorithm Implementation for Knapsack Problem
// Based on Python implementation from GA_knapsack_test.ipynb

module genetic_algorithm #(
    parameter POPULATION_SIZE = 150,
    parameter CHROMOSOME_LENGTH = 128,
    parameter MAX_GENERATIONS = 300,
    parameter TOURNAMENT_SIZE = 5,
    parameter SEED = 42
)(
    input wire clk,
    input wire rst,
    input wire start,
    
    // Item values and weights (8 bits per item)
    input wire [CHROMOSOME_LENGTH*8-1:0] item_values,
    input wire [CHROMOSOME_LENGTH*8-1:0] item_weights,
    input wire [15:0] capacity,
    
    // Outputs
    output reg [CHROMOSOME_LENGTH-1:0] best_solution,
    output reg [15:0] best_fitness,
    output reg [9:0] generation_count,
    output reg done
);

// State machine states
localparam IDLE = 4'd0;
localparam INIT_POP = 4'd1;
localparam EVALUATE = 4'd2;
localparam SELECTION = 4'd3;
localparam CROSSOVER = 4'd4;
localparam MUTATION = 4'd5;
localparam UPDATE_BEST = 4'd6;
localparam CHECK_TERM = 4'd7;
localparam FINISHED = 4'd8;

reg [3:0] state;
reg [3:0] next_state;

// Population memory
reg [CHROMOSOME_LENGTH-1:0] population [0:POPULATION_SIZE-1];
reg [CHROMOSOME_LENGTH-1:0] new_population [0:POPULATION_SIZE-1];
reg [15:0] fitness_values [0:POPULATION_SIZE-1];

// Indices and counters
reg [7:0] pop_index;
reg [7:0] eval_index;
reg [7:0] select_index;
reg [9:0] current_gen;
reg [7:0] no_improvement;

// Best solution tracking
reg [CHROMOSOME_LENGTH-1:0] best_individual;
reg [15:0] current_best_fitness;

// Random number generation (LFSR)
reg [31:0] lfsr;
wire feedback;
assign feedback = lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0];

// Parameters for GA operations
reg [7:0] elite_size;
reg [15:0] mutation_rate; // Fixed point: 0.008 * 2^16 = 524
reg [15:0] crossover_rate; // Fixed point: 0.85 * 2^16 = 55705

// Fitness calculation function
function [15:0] calculate_fitness;
    input [CHROMOSOME_LENGTH-1:0] individual;
    input [CHROMOSOME_LENGTH*8-1:0] values;
    input [CHROMOSOME_LENGTH*8-1:0] weights;
    input [15:0] cap;
    
    reg [15:0] total_value;
    reg [15:0] total_weight;
    reg [7:0] item_val;
    reg [7:0] item_wgt;
    integer i;
    
    begin
        total_value = 16'd0;
        total_weight = 16'd0;
        
        for (i = 0; i < CHROMOSOME_LENGTH; i = i + 1) begin
            if (individual[i] == 1'b1) begin
                item_val = values[i*8 +: 8];
                item_wgt = weights[i*8 +: 8];
                total_value = total_value + item_val;
                total_weight = total_weight + item_wgt;
            end
        end
        
        // Penalty mode implementation - softer penalty
        if (total_weight > cap) begin
            // Softer penalty to allow exploration
            if (total_weight - cap > 16'd200) begin
                // Severe penalty for very overweight
                calculate_fitness = total_value >> 2; // Divide by 4
            end else begin
                // Proportional penalty
                calculate_fitness = total_value - ((total_weight - cap) * 2);
            end
        end else begin
            calculate_fitness = total_value;
        end
    end
endfunction

// LFSR random number generator
always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr <= SEED;
    end else begin
        lfsr <= {lfsr[30:0], feedback};
    end
end

// State machine
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

// Next state logic
always @(*) begin
    next_state = state;
    
    case (state)
        IDLE: begin
            if (start) begin
                next_state = INIT_POP;
            end
        end
        
        INIT_POP: begin
            if (pop_index >= POPULATION_SIZE) begin
                next_state = EVALUATE;
            end
        end
        
        EVALUATE: begin
            if (eval_index >= POPULATION_SIZE) begin
                next_state = SELECTION;
            end
        end
        
        SELECTION: begin
            if (select_index >= elite_size) begin
                next_state = CROSSOVER;
            end
        end
        
        CROSSOVER: begin
            if (select_index >= POPULATION_SIZE - 1) begin
                next_state = MUTATION;
            end
        end
        
        MUTATION: begin
            if (select_index >= POPULATION_SIZE) begin
                next_state = UPDATE_BEST;
            end
        end
        
        UPDATE_BEST: begin
            if (eval_index >= POPULATION_SIZE) begin
                next_state = CHECK_TERM;
            end
        end
        
        CHECK_TERM: begin
            if (current_gen >= MAX_GENERATIONS - 1 || no_improvement > 50) begin
                next_state = FINISHED;
            end else begin
                next_state = SELECTION;
            end
        end
        
        FINISHED: begin
            next_state = IDLE;
        end
        
        default: next_state = IDLE;
    endcase
end

// Main GA operations
integer i, j;
reg [15:0] temp_fitness;
reg [7:0] tournament_winner;
reg [15:0] best_tournament_fit;
reg [CHROMOSOME_LENGTH-1:0] parent1, parent2, child1, child2;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        pop_index <= 8'd0;
        eval_index <= 8'd0;
        select_index <= 8'd0;
        current_gen <= 10'd0;
        no_improvement <= 8'd0;
        done <= 1'b0;
        current_best_fitness <= 16'd0;
        elite_size <= 8'd4; // Increased elitism
        mutation_rate <= 16'd524; // 0.008 in fixed point
        crossover_rate <= 16'd55705; // 0.85 in fixed point
        best_solution <= {CHROMOSOME_LENGTH{1'b0}};
        best_fitness <= 16'd0;
        generation_count <= 10'd0;
        
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    done <= 1'b0;
                    current_gen <= 10'd0;
                    pop_index <= 8'd0;
                    no_improvement <= 8'd0;
                    current_best_fitness <= 16'd0;
                end
            end
            
            INIT_POP: begin
                if (pop_index < POPULATION_SIZE) begin
                    // Initialize population with mixed strategy
                    for (j = 0; j < CHROMOSOME_LENGTH; j = j + 1) begin
                        if (pop_index < POPULATION_SIZE / 3) begin
                            // 33% random initialization
                            population[pop_index][j] <= lfsr[(j + pop_index) % 32];
                        end else if (pop_index < 2 * POPULATION_SIZE / 3) begin
                            // 33% biased towards fewer items
                            population[pop_index][j] <= (lfsr[(j + pop_index) % 32] && 
                                                         lfsr[(j + pop_index + 1) % 32] && 
                                                         lfsr[(j + pop_index + 2) % 32]) ? 1'b1 : 1'b0;
                        end else begin
                            // 33% biased towards more items
                            population[pop_index][j] <= (lfsr[(j + pop_index) % 32] || 
                                                         lfsr[(j + pop_index + 1) % 32]) ? 1'b1 : 1'b0;
                        end
                    end
                    // Rotate LFSR for next individual
                    lfsr <= {lfsr[30:0], feedback};
                    pop_index <= pop_index + 1;
                end else begin
                    pop_index <= 8'd0;
                    eval_index <= 8'd0;
                end
            end
            
            EVALUATE: begin
                if (eval_index < POPULATION_SIZE) begin
                    fitness_values[eval_index] <= calculate_fitness(
                        population[eval_index],
                        item_values,
                        item_weights,
                        capacity
                    );
                    eval_index <= eval_index + 1;
                end else begin
                    eval_index <= 8'd0;
                    select_index <= 8'd0;
                end
            end
            
            SELECTION: begin
                // Elitism: Keep best individuals with proper sorting
                if (select_index < elite_size) begin
                    // Find best individual not yet selected
                    best_tournament_fit = 16'd0;
                    tournament_winner = 8'd0;
                    
                    for (i = 0; i < POPULATION_SIZE; i = i + 1) begin
                        if (fitness_values[i] > best_tournament_fit) begin
                            // Check if not already selected
                            if (select_index == 0 || 
                                (select_index == 1 && i != lfsr[23:16])) begin
                                best_tournament_fit = fitness_values[i];
                                tournament_winner = i;
                            end
                        end
                    end
                    
                    new_population[select_index] <= population[tournament_winner];
                    if (select_index == 0) lfsr[23:16] <= tournament_winner; // Remember first elite
                    select_index <= select_index + 1;
                end else begin
                    select_index <= elite_size;
                end
            end
            
            CROSSOVER: begin
                if (select_index < POPULATION_SIZE - 1) begin
                    // Proper tournament selection for parent1
                    best_tournament_fit = 16'd0;
                    tournament_winner = 8'd0;
                    for (i = 0; i < TOURNAMENT_SIZE; i = i + 1) begin
                        j = (lfsr[i*5 +: 5] + (lfsr[20:13] * i)) % POPULATION_SIZE;
                        if (fitness_values[j] > best_tournament_fit) begin
                            best_tournament_fit = fitness_values[j];
                            tournament_winner = j;
                        end
                    end
                    parent1 = population[tournament_winner];
                    
                    // Proper tournament selection for parent2
                    best_tournament_fit = 16'd0;
                    for (i = 0; i < TOURNAMENT_SIZE; i = i + 1) begin
                        j = (lfsr[(i+5)*5 +: 5] + (lfsr[27:20] * i)) % POPULATION_SIZE;
                        if (fitness_values[j] > best_tournament_fit) begin
                            best_tournament_fit = fitness_values[j];
                            tournament_winner = j;
                        end
                    end
                    parent2 = population[tournament_winner];
                    
                    // Multi-point crossover (3 points)
                    if (lfsr[16] || lfsr[17]) begin  // Higher crossover probability
                        // Define crossover points
                        for (j = 0; j < CHROMOSOME_LENGTH; j = j + 1) begin
                            if (j < 32) begin
                                child1[j] = parent1[j];
                                child2[j] = parent2[j];
                            end else if (j < 64) begin
                                child1[j] = parent2[j];
                                child2[j] = parent1[j];
                            end else if (j < 96) begin
                                child1[j] = parent1[j];
                                child2[j] = parent2[j];
                            end else begin
                                child1[j] = parent2[j];
                                child2[j] = parent1[j];
                            end
                        end
                    end else begin
                        child1 = parent1;
                        child2 = parent2;
                    end
                    
                    new_population[select_index] <= child1;
                    if (select_index + 1 < POPULATION_SIZE) begin
                        new_population[select_index + 1] <= child2;
                    end
                    
                    select_index <= select_index + 2;
                end else begin
                    select_index <= 8'd0;
                end
            end
            
            MUTATION: begin
                if (select_index < POPULATION_SIZE) begin
                    // Apply adaptive mutation
                    for (j = 0; j < CHROMOSOME_LENGTH; j = j + 1) begin
                        // Variable mutation rate based on stagnation
                        if (no_improvement > 20) begin
                            // High mutation when stuck
                            if (lfsr[(j + select_index) % 32] && 
                                lfsr[(j + select_index + 1) % 32]) begin
                                new_population[select_index][j] <= ~new_population[select_index][j];
                            end
                        end else if (no_improvement > 10) begin
                            // Medium mutation
                            if (lfsr[(j + select_index) % 32] && 
                                lfsr[(j + select_index + 1) % 32] && 
                                lfsr[(j + select_index + 2) % 32]) begin
                                new_population[select_index][j] <= ~new_population[select_index][j];
                            end
                        end else begin
                            // Low mutation when improving
                            if (lfsr[(j + select_index) % 32] && 
                                lfsr[(j + select_index + 1) % 32] && 
                                lfsr[(j + select_index + 2) % 32] && 
                                lfsr[(j + select_index + 3) % 32] == 1'b0) begin
                                new_population[select_index][j] <= ~new_population[select_index][j];
                            end
                        end
                    end
                    select_index <= select_index + 1;
                end else begin
                    // Diversity injection if stuck
                    if (no_improvement > 30) begin
                        // Replace worst 10% with random individuals
                        for (i = POPULATION_SIZE - 15; i < POPULATION_SIZE; i = i + 1) begin
                            for (j = 0; j < CHROMOSOME_LENGTH; j = j + 1) begin
                                new_population[i][j] <= lfsr[(i + j) % 32];
                            end
                        end
                        no_improvement <= no_improvement - 10; // Reset counter partially
                    end
                    // Copy new population to current
                    for (i = 0; i < POPULATION_SIZE; i = i + 1) begin
                        population[i] <= new_population[i];
                    end
                    eval_index <= 8'd0;
                end
            end
            
            UPDATE_BEST: begin
                if (eval_index < POPULATION_SIZE) begin
                    temp_fitness = calculate_fitness(
                        population[eval_index],
                        item_values,
                        item_weights,
                        capacity
                    );
                    fitness_values[eval_index] <= temp_fitness;
                    
                    if (temp_fitness > current_best_fitness) begin
                        current_best_fitness <= temp_fitness;
                        best_individual <= population[eval_index];
                        no_improvement <= 8'd0;
                    end
                    
                    eval_index <= eval_index + 1;
                end else begin
                    no_improvement <= no_improvement + 1;
                    eval_index <= 8'd0;
                end
            end
            
            CHECK_TERM: begin
                if (current_gen >= MAX_GENERATIONS - 1 || no_improvement > 50) begin
                    best_solution <= best_individual;
                    best_fitness <= current_best_fitness;
                    generation_count <= current_gen;
                end else begin
                    current_gen <= current_gen + 1;
                    select_index <= 8'd0;
                    
                    // Adaptive mutation rate
                    if (no_improvement > 5) begin
                        if (mutation_rate < 16'd9830) begin // 0.15 in fixed point
                            mutation_rate <= mutation_rate + (mutation_rate >> 4); // Multiply by ~1.06
                        end
                    end else begin
                        mutation_rate <= 16'd419; // 0.008 * 0.8 in fixed point
                    end
                end
            end
            
            FINISHED: begin
                done <= 1'b1;
            end
        endcase
    end
end

endmodule
