test_file: 
	nvim --headless -c "PlenaryBustedFile tests/unit/$(filename)"

test:
	nvim --headless -c "PlenaryBustedDirectory tests"

lint:
	stylua --check .
