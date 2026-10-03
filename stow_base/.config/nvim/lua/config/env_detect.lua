local M = {}

function M.detect_and_ask()
  local cwd = vim.fn.getcwd()
  
  -- Prevent asking multiple times for the same directory in one session
  if vim.g.env_asked_for == cwd then return end
  vim.g.env_asked_for = cwd

  local envs = {}

  -- 1. Python Standard / UV / Poetry Venvs
  local venv_dirs = { ".venv", "venv", "env", ".env" }
  for _, v in ipairs(venv_dirs) do
    local path = cwd .. "/" .. v
    if vim.fn.isdirectory(path) == 1 then
      table.insert(envs, { name = v, path = path, type = "python" })
      break
    end
  end

  -- 2. Pixi
  if vim.fn.filereadable(cwd .. "/pixi.toml") == 1 and vim.fn.isdirectory(cwd .. "/.pixi/envs/default") == 1 then
    table.insert(envs, { name = "pixi", path = cwd .. "/.pixi/envs/default", type = "pixi" })
  end

  -- 3. Cargo (Rust)
  if vim.fn.filereadable(cwd .. "/Cargo.toml") == 1 then
    table.insert(envs, { name = "cargo", path = cwd, type = "cargo" })
  end
  
  -- 4. Node (npm / pnpm / yarn)
  if vim.fn.filereadable(cwd .. "/package.json") == 1 and vim.fn.isdirectory(cwd .. "/node_modules") == 1 then
    table.insert(envs, { name = "node", path = cwd .. "/node_modules", type = "node" })
  end

  if #envs == 0 then return end

  -- Ask for the first detected environment
  local env = envs[1]
  
  -- Delay the prompt slightly so Noice/UI has fully loaded during VimEnter
  vim.defer_fn(function()
    vim.ui.select({ "Yes", "No" }, {
      prompt = string.format("Folder has a '%s' env. Do you want to activate it?", env.name),
    }, function(choice)
      if choice == "Yes" then
        if env.type == "python" or env.type == "pixi" then
          vim.env.VIRTUAL_ENV = env.path
          vim.env.PATH = env.path .. "/bin:" .. vim.env.PATH
          
          if env.type == "python" then
            vim.g.python3_host_prog = env.path .. "/bin/python"
          end
          
          vim.notify("Activated " .. env.name .. " environment! PATH updated.", vim.log.levels.INFO, { title = "Environment" })
          
          -- Restart LSP so pyright picks up the new Python paths
          vim.cmd("silent! LspRestart")
          
        elseif env.type == "node" then
          vim.env.PATH = env.path .. "/.bin:" .. vim.env.PATH
          vim.notify("Activated " .. env.name .. " environment! Local binaries added to PATH.", vim.log.levels.INFO, { title = "Environment" })
          vim.cmd("silent! LspRestart")
          
        elseif env.type == "cargo" then
          vim.notify("Cargo project recognized. Rust Analyzer will use this root.", vim.log.levels.INFO, { title = "Environment" })
        end
      end
    end)
  end, 200)
end

function M.setup()
  vim.api.nvim_create_autocmd({ "VimEnter", "DirChanged" }, {
    group = vim.api.nvim_create_augroup("EnvDetector", { clear = true }),
    callback = M.detect_and_ask,
  })
end

return M
