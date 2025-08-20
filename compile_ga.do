# ModelSim compilation script for Genetic Algorithm
# Run this script in ModelSim with: do compile_ga.do

# Create work library if it doesn't exist
vlib work

# Compile the design files
echo "Compiling GA design files..."
vlog -work work GA_test.v
vlog -work work GA_test_tb.v

echo "Compilation complete!"
echo "To run simulation, execute: do run_ga.do"