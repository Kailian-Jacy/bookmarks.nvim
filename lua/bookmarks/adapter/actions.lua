local repo = require("bookmarks.repo")
local api = require("bookmarks.api")
local utils = require("bookmarks.utils")
local domain = require("bookmarks.domain")

local actions = {}

function actions.new_list(on_confirm)
  vim.ui.input({ prompt = "Enter the name of the new list: " }, function(input)
    if not input then
      return
    end
    local name = vim.trim(input) ~= "" and input or tostring(os.time())
    local newlist = api.add_list({ name = name })
    if on_confirm then
      on_confirm()
    end
    api.mark({ name = "", list_name = newlist.name })
  end)
end

function actions.rename_list(bookmark_list, on_confirm)
    vim.ui.input({ prompt = "Enter new name: " }, function(input)
      if not input then
        return
      end
      api.rename_bookmark_list(input, bookmark_list.name)
      if on_confirm then 
        on_confirm()
      end
      utils.log("bookmark_list renamed from: " .. bookmark_list.name .. " to " .. input, vim.log.levels.INFO)
    end)
end

function actions.delete_list(bookmark_list)
    if not bookmark_list then
      return
    end
    vim.ui.input({ prompt = "Are you sure you want to delete list" .. bookmark_list.name .. "? Y/N" }, function(input)
      if input == "Y" then
        repo.bookmark_list.write.delete(bookmark_list.name)
        vim.notify(bookmark_list.name .. " list deleted")
      else
        vim.notify("deletion abort")
        return
      end
  end)
end

function actions.set_active_list(bookmark_list)
    api.set_active_list(bookmark_list.name)
end

function actions.mark_to_list()
    vim.print("todo.")
end

function actions.rename_bookmark(bookmark, on_confirm)
    vim.ui.input({ prompt = "New name of the bookmark" }, function(input)
      if input then
        api.rename_bookmark(bookmark.id, input or "")
        if on_confirm then
          on_confirm()
        end
      end
  end)
end

function actions.delete_bookmark(bookmark)
    repo.mark.write.delete(bookmark)
end

function actions.grep_marked_files()
  local ok, fzf_lua = pcall(require, "fzf-lua")
  if not ok then
    return utils.log("this command requires fzf-lua plugin", vim.log.levels.ERROR)
  end

  local opts = {}
  opts.prompt = "rg> "
  opts.git_icons = true
  opts.file_icons = true
  opts.color_icons = true
  opts.actions = fzf_lua.defaults.actions.files
  opts.fzf_opts = { ["--layout"] = "reverse-list" }
  opts.previewer = "builtin"
  opts.winopts = {
    split = "belowright new",
  }
  opts.fn_transform = function(x)
    return fzf_lua.make_entry.file(x, opts)
  end

  local list = repo.bookmark_list.write.find_or_set_active()
  local bookmarks = list.bookmarks
  local projects = repo.project.findall()
  local filepathes = ""
  for _, b in ipairs(bookmarks) do
    local fullpath = domain.bookmark.fullpath(b, projects)
    filepathes = filepathes .. " " .. fullpath
  end

  fzf_lua.fzf_live("rg --column --color=always <query> " .. filepathes .. " 2>/dev/null", opts)
end

return actions
