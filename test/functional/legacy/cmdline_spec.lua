local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local command = n.command
local feed = n.feed
local feed_command = n.feed_command
local exec = n.exec
local api = n.api
local pesc = vim.pesc

describe('cmdline', function()
  before_each(clear)

  -- oldtest: Test_cmdlineclear_tabenter()
  it('is cleared when switching tabs', function()
    local screen = Screen.new(30, 10)

    feed_command([[call setline(1, range(30))]])
    screen:expect([[
      ^0                             |
      1                             |
      2                             |
      3                             |
      4                             |
      5                             |
      6                             |
      7                             |
      8                             |
      :call setline(1, range(30))   |
    ]])

    feed [[:tabnew<cr>]]
    screen:expect {
      grid = [[
      {24: + [No Name] }{5: [No Name] }{2:     }{24:X}|
      ^                              |
      {1:~                             }|*7
      :tabnew                       |
    ]],
    }

    feed [[<C-w>-<C-w>-]]
    screen:expect {
      grid = [[
      {24: + [No Name] }{5: [No Name] }{2:     }{24:X}|
      ^                              |
      {1:~                             }|*5
                                    |*3
    ]],
    }

    feed [[gt]]
    screen:expect {
      grid = [[
      {5: + [No Name] }{24: [No Name] }{2:     }{24:X}|
      ^0                             |
      1                             |
      2                             |
      3                             |
      4                             |
      5                             |
      6                             |
      7                             |
                                    |
    ]],
    }

    feed [[gt]]
    screen:expect([[
      {24: + [No Name] }{5: [No Name] }{2:     }{24:X}|
      ^                              |
      {1:~                             }|*5
                                    |*3
    ]])
  end)

  -- oldtest: Test_verbose_option()
  it('prints every executed Ex command if verbose >= 16', function()
    local screen = Screen.new(60, 12)
    exec([[
      command DoSomething echo 'hello' |set ts=4 |let v = '123' |echo v
      call feedkeys("\r", 't') " for the hit-enter prompt
      set verbose=20
    ]])
    feed_command('DoSomething')
    screen:expect([[
                                                                  |
      {1:~                                                           }|*2
      {3:                                                            }|
      Executing: DoSomething                                      |
      Executing: echo 'hello' |set ts=4 |let v = '123' |echo v    |
      hello                                                       |
      Executing: set ts=4 |let v = '123' |echo v                  |
      Executing: let v = '123' |echo v                            |
      Executing: echo v                                           |
      123                                                         |
      {6:Press ENTER or type command to continue}^                     |
    ]])
  end)

  -- oldtest: Test_cmdline_redraw_tabline()
  it('tabline is redrawn on entering cmdline', function()
    local screen = Screen.new(30, 6)
    exec([[
      set showtabline=2
      autocmd CmdlineEnter * set tabline=foo
    ]])
    feed(':')
    screen:expect([[
      {2:foo                           }|
                                    |
      {1:~                             }|*3
      :^                             |
    ]])
  end)

  -- oldtest: Test_redraw_in_autocmd()
  it('cmdline cursor position is correct after :redraw with cmdheight=2', function()
    local screen = Screen.new(30, 6)
    exec([[
      set cmdheight=2
      autocmd CmdlineChanged * redraw
    ]])
    feed(':for i in range(3)<CR>')
    screen:expect([[
                                    |
      {1:~                             }|*3
      :for i in range(3)            |
      :  ^                           |
    ]])
    feed(':let i =')
    -- Note: this may still be considered broken, ref #18140
    screen:expect([[
                                    |
      {1:~                             }|*3
      :  :let i =^                   |
                                    |
    ]])
  end)

  -- oldtest: Test_changing_cmdheight()
  it("changing 'cmdheight'", function()
    local screen = Screen.new(60, 8)
    exec([[
      set cmdheight=1 laststatus=2
      func EchoOne()
        set laststatus=2 cmdheight=1
        echo 'foo'
        echo 'bar'
        set cmdheight=2
      endfunc
      func EchoTwo()
        set laststatus=2
        set cmdheight=5
        echo 'foo'
        echo 'bar'
        set cmdheight=1
      endfunc
    ]])

    feed(':resize -3<CR>')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*2
      {3:[No Name]                                                   }|
                                                                  |*4
    ]])

    -- :resize now also changes 'cmdheight' accordingly
    feed(':set cmdheight+=1<CR>')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|
      {3:[No Name]                                                   }|
                                                                  |*5
    ]])

    -- using more space moves the status line up
    feed(':set cmdheight+=1<CR>')
    screen:expect([[
      ^                                                            |
      {3:[No Name]                                                   }|
                                                                  |*6
    ]])

    -- reducing cmdheight moves status line down
    feed(':set cmdheight-=3<CR>')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*3
      {3:[No Name]                                                   }|
                                                                  |*3
    ]])

    -- reducing window size and then setting cmdheight
    feed(':resize -1<CR>')
    feed(':set cmdheight=1<CR>')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*5
      {3:[No Name]                                                   }|
                                                                  |
    ]])

    -- setting 'cmdheight' works after outputting two messages
    feed(':call EchoTwo()')
    screen:expect([[
                                                                  |
      {1:~                                                           }|*5
      {3:[No Name]                                                   }|
      :call EchoTwo()^                                             |
    ]])
    feed('<CR>')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*5
      {3:[No Name]                                                   }|
                                                                  |
    ]])

    -- increasing 'cmdheight' doesn't clear the messages that need hit-enter
    feed(':call EchoOne()<CR>')
    screen:expect([[
                                                                  |
      {1:~                                                           }|*3
      {3:                                                            }|
      foo                                                         |
      bar                                                         |
      {6:Press ENTER or type command to continue}^                     |
    ]])

    -- window commands do not reduce 'cmdheight' to value lower than :set by user
    feed('<CR>:wincmd _<CR>')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*4
      {3:[No Name]                                                   }|
      :wincmd _                                                   |
                                                                  |
    ]])
  end)

  -- oldtest: Test_cmdheight_tabline()
  it("changing 'cmdheight' when there is a tabline", function()
    local screen = Screen.new(60, 8)
    api.nvim_set_option_value('laststatus', 2, {})
    api.nvim_set_option_value('showtabline', 2, {})
    api.nvim_set_option_value('cmdheight', 1, {})
    screen:expect([[
      {5: [No Name] }{2:                                                 }|
      ^                                                            |
      {1:~                                                           }|*4
      {3:[No Name]                                                   }|
                                                                  |
    ]])
  end)

  -- oldtest: Test_rulerformat_position()
  it("ruler has correct position with 'rulerformat' set", function()
    local screen = Screen.new(20, 3)
    api.nvim_set_option_value('ruler', true, {})
    api.nvim_set_option_value('rulerformat', 'longish', {})
    api.nvim_set_option_value('laststatus', 0, {})
    api.nvim_set_option_value('winwidth', 1, {})
    feed [[<C-W>v<C-W>|<C-W>p]]
    screen:expect [[
                        │^ |
      {1:~                 }│{1:~}|
                longish   |
    ]]
  end)

  -- oldtest: Test_rulerformat_function()
  it("'rulerformat' can use %!", function()
    local screen = Screen.new(40, 2)
    exec([[
      func TestRulerFn()
        return '10,20%=30%%'
      endfunc
    ]])
    api.nvim_set_option_value('ruler', true, {})
    api.nvim_set_option_value('rulerformat', '%!TestRulerFn()', {})
    screen:expect([[
      ^                                        |
                            10,20         30% |
    ]])
  end)
end)

describe('cmdwin', function()
  before_each(clear)

  -- oldtest: Test_cmdwin_interrupted()
  it('still uses a new buffer when interrupting more prompt on open', function()
    local screen = Screen.new(30, 16)
    screen:set_default_attr_ids({
      [0] = { bold = true, foreground = Screen.colors.Blue }, -- NonText
      [1] = { bold = true, reverse = true }, -- StatusLine
      [2] = { reverse = true }, -- StatusLineNC
      [3] = { bold = true, foreground = Screen.colors.SeaGreen }, -- MoreMsg
      [4] = { bold = true }, -- ModeMsg
    })
    command('set more')
    command('autocmd WinNew * highlight')
    feed('q:')
    screen:expect({ any = pesc('{3:-- More --}^') })
    feed('q')
    screen:expect([[
                                    |
      {0:~                             }|*5
      {2:[No Name]                     }|
      {0::}^                             |
      {0:~                             }|*6
      {1:[Command Line]                }|
                                    |
    ]])
    feed([[aecho 'done']])
    screen:expect([[
                                    |
      {0:~                             }|*5
      {2:[No Name]                     }|
      {0::}echo 'done'^                  |
      {0:~                             }|*6
      {1:[Command Line]                }|
      {4:-- INSERT --}                  |
    ]])
    feed('<CR>')
    screen:expect([[
      ^                              |
      {0:~                             }|*14
      done                          |
    ]])
  end)
end)
