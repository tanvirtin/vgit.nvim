test_file: 
	nvim --headless -c "PlenaryBustedFile $(filename)"

test:
	nvim --headless -c "PlenaryBustedDirectory tests"

lint:
	stylua --check .
