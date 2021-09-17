test:
	nvim --headless -c "PlenaryBustedDirectory tests"

lint:
	stylua --check .
