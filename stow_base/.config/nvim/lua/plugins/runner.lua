return {
  {
    "CRAG666/code_runner.nvim",
    dependencies = "nvim-lua/plenary.nvim",
    cmd = { "RunCode", "RunFile", "RunProject", "RunClose" },
    keys = {
      { "<leader>rr", "<cmd>RunCode<cr>", desc = "Run Code (Smart Detect)" },
      { "<leader>rf", "<cmd>RunFile<cr>", desc = "Run Single File" },
      { "<leader>rp", "<cmd>RunProject<cr>", desc = "Run Project" },
      { "<leader>rx", "<cmd>RunClose<cr>", desc = "Close Runner" },
    },
    config = function()
      require("code_runner").setup({
        mode = "toggleterm",
        focus = true,
        startinsert = false,
        term = {
          position = "float",
          size = 15,
        },
        filetype = {
          python = "python3 -u",
          rust = "cd $dir && rustc $fileName && $dir/$fileNameWithoutExt",
          c = "cd $dir && gcc $fileName -o $fileNameWithoutExt && $dir/$fileNameWithoutExt",
          cpp = "cd $dir && g++ $fileName -o $fileNameWithoutExt && $dir/$fileNameWithoutExt",
          javascript = "node",
          typescript = "npx ts-node",
          sh = "bash",
          lua = "lua",
          go = "go run",
        },
        project = {
          -- Users can create a `.code_runner.json` in their project root to override this per-project!
        },
      })
    end,
  },
}
