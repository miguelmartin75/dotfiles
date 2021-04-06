local _0_0 = nil
do
  local name_0_ = "dotfiles.util"
  local module_0_ = nil
  do
    local x_0_ = package.loaded[name_0_]
    if ("table" == type(x_0_)) then
      module_0_ = x_0_
    else
      module_0_ = {}
    end
  end
  module_0_["aniseed/module"] = name_0_
  module_0_["aniseed/locals"] = ((module_0_)["aniseed/locals"] or {})
  module_0_["aniseed/local-fns"] = ((module_0_)["aniseed/local-fns"] or {})
  package.loaded[name_0_] = module_0_
  _0_0 = module_0_
end
local function _1_(...)
  local ok_3f_0_, val_0_ = nil, nil
  local function _1_()
    return {require("aniseed.nvim")}
  end
  ok_3f_0_, val_0_ = pcall(_1_)
  if ok_3f_0_ then
    _0_0["aniseed/local-fns"] = {require = {nvim = "aniseed.nvim"}}
    return val_0_
  else
    return print(val_0_)
  end
end
local _local_0_ = _1_(...)
local nvim = _local_0_[1]
local _2amodule_2a = _0_0
local _2amodule_name_2a = "dotfiles.util"
do local _ = ({nil, _0_0, {{}, nil, nil, nil}})[2] end
local expand = nil
do
  local v_0_ = nil
  do
    local v_0_0 = nil
    local function expand0(path)
      return nvim.fn.expand(path)
    end
    v_0_0 = expand0
    _0_0["expand"] = v_0_0
    v_0_ = v_0_0
  end
  local t_0_ = (_0_0)["aniseed/locals"]
  t_0_["expand"] = v_0_
  expand = v_0_
end
local glob = nil
do
  local v_0_ = nil
  do
    local v_0_0 = nil
    local function glob0(path)
      return nvim.fn.glob(path, true, true, true)
    end
    v_0_0 = glob0
    _0_0["glob"] = v_0_0
    v_0_ = v_0_0
  end
  local t_0_ = (_0_0)["aniseed/locals"]
  t_0_["glob"] = v_0_
  glob = v_0_
end
local exists_3f = nil
do
  local v_0_ = nil
  do
    local v_0_0 = nil
    local function exists_3f0(path)
      return (nvim.fn.filereadable(path) == 1)
    end
    v_0_0 = exists_3f0
    _0_0["exists?"] = v_0_0
    v_0_ = v_0_0
  end
  local t_0_ = (_0_0)["aniseed/locals"]
  t_0_["exists?"] = v_0_
  exists_3f = v_0_
end
local lua_file = nil
do
  local v_0_ = nil
  do
    local v_0_0 = nil
    local function lua_file0(path)
      return nvim.ex.luafile(path)
    end
    v_0_0 = lua_file0
    _0_0["lua-file"] = v_0_0
    v_0_ = v_0_0
  end
  local t_0_ = (_0_0)["aniseed/locals"]
  t_0_["lua-file"] = v_0_
  lua_file = v_0_
end
local config_path = nil
do
  local v_0_ = nil
  do
    local v_0_0 = nvim.fn.stdpath("config")
    _0_0["config-path"] = v_0_0
    v_0_ = v_0_0
  end
  local t_0_ = (_0_0)["aniseed/locals"]
  t_0_["config-path"] = v_0_
  config_path = v_0_
end
local nnoremap = nil
do
  local v_0_ = nil
  do
    local v_0_0 = nil
    local function nnoremap0(from, to)
      return nvim.set_keymap("n", ("<leader>" .. from), (":" .. to .. "<cr>"), {noremap = true})
    end
    v_0_0 = nnoremap0
    _0_0["nnoremap"] = v_0_0
    v_0_ = v_0_0
  end
  local t_0_ = (_0_0)["aniseed/locals"]
  t_0_["nnoremap"] = v_0_
  nnoremap = v_0_
end
return nil