((nil . ((my/project-commands
          . (("Compile" . "python -m py_compile run.py")
             ("Test" . "./run.py --help")
             ("Check" . "uv run --with ruff ruff check run.py")
             ("Fix" . "uv run --with ruff ruff check --fix run.py"))))))
