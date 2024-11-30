local actions = require("bookmarks.adapter.actions")
local api = require("bookmarks.api")
local picker = require("bookmarks.adapter.picker")

---@class Bookmark.Command
---@field name string
---@field callback fun(): nil
---@field description? string

-- TODO: a helper function to generate this structure to markdown table to put into README file

---@type Bookmark.Command[]
local commands = {

  {
    name = "[List] new",
    callback = actions.new_list,
    description = "create a new BookmarkList and set it to active and mark current line into this BookmarkList",
  },
  {
    name = "[List] Browsing all lists",
    callback = function()
      picker.pick_bookmark_list()
    end,
    description = "",
  },
  {
    name = "[Mark] mark to list",
    callback = actions.mark_to_list,
    description = "bookmark current line and add it to specific bookmark list",
  },
  {
    name = "[Mark] Browsing all marks",
    callback = function()
      picker.pick_bookmark({ all = true })
    end,
    description = "",
  },
  {
    name = "[Mark] Bookmarks of current project",
    callback = function()
      picker.pick_bookmark_of_current_project({ all = true })
    end,
    description = "",
  },
  {
    name = "[Mark] grep the marked files",
    callback = actions.grep_marked_files,
    description = "grep in all the files that contain bookmarks",
  },
}

return {
  commands = commands,
}
