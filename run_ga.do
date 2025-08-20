# ModelSim simulation run script for Genetic Algorithm
# Run this script after compilation with: do run_ga.do

# Load the simulation
vsim -novopt work.GA_test_tb

# Add all signals to wave window
add wave -divider "Control Signals"
add wave sim:/GA_test_tb/clk
add wave sim:/GA_test_tb/rst
add wave sim:/GA_test_tb/start
add wave sim:/GA_test_tb/done

add wave -divider "GA State Machine"
add wave -radix unsigned sim:/GA_test_tb/dut/state
add wave -radix unsigned sim:/GA_test_tb/dut/current_gen
add wave -radix unsigned sim:/GA_test_tb/dut/no_improvement

add wave -divider "Results"
add wave -radix unsigned sim:/GA_test_tb/best_fitness
add wave -radix unsigned sim:/GA_test_tb/generation_count
add wave -radix hexadecimal sim:/GA_test_tb/best_solution

add wave -divider "Internal Monitoring"
add wave -radix unsigned sim:/GA_test_tb/dut/current_best_fitness
add wave -radix unsigned sim:/GA_test_tb/dut/pop_index
add wave -radix unsigned sim:/GA_test_tb/dut/eval_index
add wave -radix unsigned sim:/GA_test_tb/dut/select_index

# Configure wave window
configure wave -namecolwidth 200
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2

# Run simulation
echo "Starting GA simulation..."
run -all

# Zoom to fit the entire simulation
wave zoom full

echo "Simulation complete!"
echo "Check the transcript for results and the wave window for signals"