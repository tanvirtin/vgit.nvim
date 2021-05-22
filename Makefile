test:
	nvim --headless -c "PlenaryBustedDirectory tests"

lint:
	luacheck lua/vgit
