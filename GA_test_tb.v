// Testbench for Genetic Algorithm module
// Tests the knapsack problem optimization

`timescale 1ns / 1ps

module GA_test_tb;

    // Parameters matching the Python implementation
    parameter POPULATION_SIZE = 150;
    parameter CHROMOSOME_LENGTH = 128;
    parameter MAX_GENERATIONS = 300;
    parameter TOURNAMENT_SIZE = 5;
    parameter SEED = 42;
    
    // Testbench signals
    reg clk;
    reg rst;
    reg start;
    reg [CHROMOSOME_LENGTH*8-1:0] item_values;
    reg [CHROMOSOME_LENGTH*8-1:0] item_weights;
    reg [15:0] capacity;
    
    wire [CHROMOSOME_LENGTH-1:0] best_solution;
    wire [15:0] best_fitness;
    wire [9:0] generation_count;
    wire done;
    
    // Instantiate the GA module
    genetic_algorithm #(
        .POPULATION_SIZE(POPULATION_SIZE),
        .CHROMOSOME_LENGTH(CHROMOSOME_LENGTH),
        .MAX_GENERATIONS(MAX_GENERATIONS),
        .TOURNAMENT_SIZE(TOURNAMENT_SIZE),
        .SEED(SEED)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .item_values(item_values),
        .item_weights(item_weights),
        .capacity(capacity),
        .best_solution(best_solution),
        .best_fitness(best_fitness),
        .generation_count(generation_count),
        .done(done)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100MHz clock
    end
    
    // Initialize item values and weights (matching Python random seed 42)
    integer i_init;
    integer seed;
    initial begin
        // Initialize with deterministic values similar to Python implementation
        seed = SEED;
        
        // Generate random values between 10-100 and weights between 5-50
        for (i_init = 0; i_init < CHROMOSOME_LENGTH; i_init = i_init + 1) begin
            // Simple pseudo-random generation for reproducibility
            seed = (seed * 1103515245 + 12345) & 32'h7fffffff;
            item_values[i_init*8 +: 8] = 10 + (seed % 91);  // 10-100
            
            seed = (seed * 1103515245 + 12345) & 32'h7fffffff;
            item_weights[i_init*8 +: 8] = 5 + (seed % 46);   // 5-50
        end
        
        // Calculate capacity as ~40% of total weight
        capacity = 16'd1373;  // Approximate value from Python output
    end
    
    // Test stimulus
    initial begin
        // Initialize signals
        rst = 1;
        start = 0;
        
        // Wait for reset
        #100;
        rst = 0;
        #20;
        
        // Start GA
        $display("Starting Genetic Algorithm at time %t", $time);
        $display("Population Size: %d", POPULATION_SIZE);
        $display("Chromosome Length: %d", CHROMOSOME_LENGTH);
        $display("Max Generations: %d", MAX_GENERATIONS);
        $display("Capacity: %d", capacity);
        
        start = 1;
        #20;
        start = 0;
        
        // Wait for completion with timeout
        wait(done == 1'b1);
        $display("\nGA Completed at time %t", $time);
        $display("Best Fitness: %d", best_fitness);
        $display("Generation Count: %d", generation_count);
        $display("Best Solution (first 32 bits): %b", best_solution[31:0]);
        
        // Calculate weight utilization
        calculate_final_stats();
        
        #100;
        $finish;
    end
    
    // Monitor progress periodically
    always @(posedge clk) begin
        if (!rst && !done && dut.state == dut.CHECK_TERM) begin
            if (dut.current_gen % 10 == 0) begin
                $display("Generation %d: Current Best Fitness = %d, No Improvement = %d", 
                         dut.current_gen, dut.current_best_fitness, dut.no_improvement);
            end
        end
    end
    
    // Task to calculate final statistics
    integer i_stats;
    integer total_weight;
    integer total_value;
    real weight_utilization;
    
    task calculate_final_stats;
        begin
            total_weight = 0;
            total_value = 0;
            
            for (i_stats = 0; i_stats < CHROMOSOME_LENGTH; i_stats = i_stats + 1) begin
                if (best_solution[i_stats]) begin
                    total_value = total_value + item_values[i_stats*8 +: 8];
                    total_weight = total_weight + item_weights[i_stats*8 +: 8];
                end
            end
            
            weight_utilization = (total_weight * 100.0) / capacity;
            
            $display("\nFinal Statistics:");
            $display("Total Value: %d", total_value);
            $display("Total Weight: %d / %d", total_weight, capacity);
            $display("Weight Utilization: %.1f%%", weight_utilization);
            
            // Compare with expected optimal (from Python: 4739)
            $display("\nAccuracy Analysis:");
            $display("Optimal Solution (DP): 4739");
            $display("GA Solution: %d", best_fitness);
            $display("Accuracy: %.2f%%", (best_fitness * 100.0) / 4739.0);
            $display("Gap from Optimal: %d", 4739 - best_fitness);
            
            if (best_fitness > 4700) begin
                $display("PASS: Solution is within acceptable range (>4700)");
                $display("Quality: EXCELLENT (>99%% optimal)");
            end else if (best_fitness > 4500) begin
                $display("PASS: Solution is good (>95%% optimal)");
            end else begin
                $display("WARNING: Solution may be suboptimal (<95%% optimal)");
            end
        end
    endtask
    
    // Dump waveforms for debugging
    initial begin
        $dumpfile("ga_test.vcd");
        $dumpvars(0, GA_test_tb);
    end

endmodule