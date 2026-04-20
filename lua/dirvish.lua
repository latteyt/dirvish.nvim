local M = {}

local function render()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)

  vim.api.nvim_buf_clear_namespace(bufnr, M.ns_id, 0, -1)
  for i, line in ipairs(lines) do
    local stat = vim.uv.fs_lstat(line)
    if stat then
      -- link refer filename
      if stat.type == "link" then
        local realpath = vim.uv.fs_realpath(line)
        vim.api.nvim_buf_set_extmark(bufnr, M.ns_id, i - 1, 0, {
          virt_text = { { " -> " .. realpath, 'NonText' } },
          virt_text_pos = "eol",
          invalidate = true,
        })
      end
      -- stat info
      local u = { "B", "K", "M", "G", "T", "P" }
      local j = math.min(#u - 1, math.max(0, math.floor(math.log(stat.size or 1, 1024))))
      local virt_text = string.format(
        "%s %5.1f%s %s", vim.fn.getfperm(line),
        stat.size / 1024 ^ j, u[j + 1],
        os.date("%Y/%m/%d %H:%M", stat.mtime.sec))

      vim.api.nvim_buf_set_extmark(bufnr, M.ns_id, i - 1, 0, {
        virt_text = { { virt_text, 'NonText' } },
        virt_text_pos = "eol_right_align",
        invalidate = true,
      })
      -- marked file highlight
      if vim.b.mark_files and vim.b.mark_files[line] then
        vim.api.nvim_buf_set_extmark(bufnr, M.ns_id, i - 1, 0, {
          end_row = i - 1,
          end_col = #line,
          hl_group = 'Todo',
          invalidate = true,
        })
      end
    end
  end
end




local function hijack(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local dirpath = vim.api.nvim_buf_get_name(bufnr)
  local stat = vim.uv.fs_stat(dirpath)
  if not stat or stat.type ~= "directory" then
    return
  end
  dirpath = string.gsub(dirpath .. '/', "/+", "/")

  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = bufnr })
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = bufnr })
  vim.api.nvim_set_option_value('buflisted', false, { buf = bufnr })
  vim.api.nvim_set_option_value('swapfile', false, { buf = bufnr })
  vim.api.nvim_set_option_value('undofile', false, { buf = bufnr })
  vim.api.nvim_set_option_value('filetype', 'dirvish', { buf = bufnr })

  vim.keymap.set('n', '<leader>r', hijack, { buffer = bufnr })
  vim.keymap.set('n', 'm', function()
    local mark_files = vim.b.mark_files or {}
    local line = vim.api.nvim_get_current_line()
    if mark_files[line] then
      mark_files[line] = nil
    else
      mark_files[line] = true
    end
    vim.b.mark_files = mark_files
    render()
  end, { buffer = bufnr })
  vim.keymap.set('x', 'm', function()
    vim.cmd('normal! \x1b')
    local mark_files = vim.b.mark_files or {}
    vim.iter(vim.fn.getline("'<", "'>")):each(function(line)
      if mark_files[line] then
        mark_files[line] = nil
      else
        mark_files[line] = true
      end
    end)
    vim.b.mark_files = mark_files
    render()
  end, { buffer = bufnr })


  local displays = {}
  for b, t in vim.fs.dir(dirpath) do
    local fullpath = dirpath .. b
    if fullpath:find('\n') then
      error(fullpath .. " contains an invalid character")
    end
    table.insert(displays,
      t == "directory" and fullpath .. "/" or fullpath
    )
  end
  local undolevels = vim.bo[bufnr].undolevels
  vim.bo[bufnr].undolevels = -1
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, displays) -- clear all text
  vim.bo[bufnr].undolevels = undolevels

  -- set the MRU file path
  for _, o in ipairs(vim.v.oldfiles) do
    for i, f in ipairs(displays) do
      if o:find(f, 1, true) then
        vim.fn.cursor(i, #dirpath)
        goto done
      end
    end
  end
  ::done::

  render()
end



local function toggle()
  local bufnr = vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(bufnr)
  local target = vim.fs.dirname(name)
  vim.cmd("edit " .. target)
end


local function shdo(paths, cmd)
  cmd = cmd:find("{}") and cmd or (cmd .. " {}")

  local lines = vim.iter(paths):fold({}, function(acc, path)
    if vim.uv.fs_stat(path) then
      local name, _ = path:gsub("/+$", "")
      local escaped = vim.fn.escape(vim.fn.shellescape(name), [[&\]])
      local result = cmd:gsub("{}", escaped)
      table.insert(acc, result)
    end
    return acc
  end)
  vim.list.unique(lines)

  local bufnr = vim.api.nvim_create_buf(false, true)
  local cwd = vim.fn.getcwd()
  vim.api.nvim_buf_set_name(bufnr, "[HACKVIM] - " .. cwd)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].undofile = false
  vim.bo[bufnr].filetype = "sh"
  vim.bo[bufnr].buftype = "acwrite"
  vim.bo[bufnr].modified = false
  vim.cmd('silent split | buffer ' .. bufnr)
  vim.cmd('lcd ' .. cwd)

  vim.api.nvim_clear_autocmds({ event = "BufWriteCmd", buffer = bufnr })
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = bufnr,
    callback = function(args)
      for _, line in ipairs(
        vim.api.nvim_buf_get_lines(args.buf, 0, -1, false)
      ) do
        if line:match("%S") then
          vim.fn.system(line)
          if vim.v.shell_error ~= 0 then
            local prompt = string.format(
              "Command failed: %s  (exit code=%d) Continue? ([Y]/N): ",
              line,
              vim.v.shell_error
            )
            local answer = vim.fn.input(prompt)
            if answer:lower() ~= "y" and answer ~= "" then
              break
            end
          end
        end
      end
      vim.bo[args.buf].modified = false
      vim.cmd('quit')
      vim.iter(vim.api.nvim_list_bufs()):each(hijack)
    end,
  })
end


M.setup = function()
  if not vim.g.loaded_netrw then
    vim.notify(
      "The 'dirvish.nvim' is incompatible with netrw. Please disable netrw.",
      vim.log.levels.ERROR
    )
    return
  end

  M.ns_id = vim.api.nvim_create_namespace("dirvish")
  M.group_id = vim.api.nvim_create_augroup("dirvish", { clear = true })
  vim.api.nvim_create_autocmd("BufAdd", {
    group = M.group_id,
    pattern = "*",
    callback = vim.schedule_wrap(function(args)
      hijack(args.buf)
    end),
  })



  vim.keymap.set('n', '-', toggle, { desc = "Toggle Dirvish" })
  vim.api.nvim_create_user_command("Shdo", function(opts)
    -- opts: {args, bang, fargs, line1, line2, range, mods}
    if opts.bang then
      shdo(vim.tbl_keys(vim.b.mark_files or {}), opts.args)
    end
    if opts.range > 0 then
      shdo(vim.fn.getline(opts.line1, opts.line2), opts.args)
    end
  end, {
    nargs = "*",
    range = true,
    bang = true,
    complete = "file",
  })


  vim.schedule(
    function()
      vim.iter(vim.api.nvim_list_bufs()):each(hijack)
    end
  )
end


return M
