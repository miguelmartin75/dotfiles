require'nvim-treesitter.configs'.setup {
  ensure_installed = "maintained", -- one of "all", "maintained" (parsers with maintainers), or a list of languages
  highlight = {
    enable = true,              -- false will disable the whole extension
  },
  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = "gnn",
      node_incremental = "grn",
      scope_incremental = "grc",
      node_decremental = "grm",
    },
  },
  --indent = {
  --  enable = true
  --}
  refactor = {
    highlight_definitions = { enable = true },
    smart_rename = {
      enable = true,
      keymaps = {
        smart_rename = "grr",
      },
    },
    --highlight_current_scope = { enable = true },
  },
}

-- Treesitter stops syntax files from being loaded so need to redefine commentstrings for
-- languages we care about.
local commentstrings = {
  python  = '#',
  json    = '#',
  bash    = '#',
  lua     = '--',
  verilog = '//'
}

require'nvim-treesitter'.define_modules {
  fixspell = {
    enable = true,
    attach = function(bufnr, lang)
      local cs = commentstrings[lang]
      vim.cmd(
        ('syntax match spellComment "%s.*" contains=@Spell'):format(cs)
      )
    end,
    detach = function(bufnr)
    end,
    is_supported = function(lang)
      if commentstrings[lang] == nil then
        return false
      end
      if require('nvim-treesitter.query').get_query(lang, 'highlights') == nil then
        return false
      end
      return true
    end
  }
}

