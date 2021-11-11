local stub = require("luassert.stub")

local methods = require("null-ls.methods")
local c = require("null-ls.config")
local u = require("null-ls.utils")

describe("lspconfig", function()
    local lspconfig = require("null-ls.lspconfig")

    -- this has side effects so we can only do it once
    lspconfig.setup()

    after_each(function()
        c.reset()
    end)

    describe("setup", function()
        it("should set up default config", function()
            local null_ls_config = require("lspconfig/configs")["null-ls"]
            assert.truthy(null_ls_config)

            local default_config = null_ls_config.document_config.default_config
            assert.equals(default_config.name, "null-ls")
            assert.equals(default_config.autostart, false)
            assert.same(default_config.cmd, { "nvim" })
            assert.same(default_config.flags, { debounce_text_changes = c.get().debounce })
            assert.same(default_config.filetypes, {})
            assert.truthy(type(default_config.root_dir) == "function")
        end)

        it("should set up autocommand", function()
            assert.truthy(vim.fn.exists("#NullLs#FileType") > 0)
        end)

        describe("root_dir", function()
            it("should return root dir", function()
                local cwd = vim.fn.getcwd()

                local root_dir = require("lspconfig/configs")["null-ls"].document_config.default_config.root_dir

                assert.equals(root_dir(cwd), cwd)
            end)
        end)
    end)

    describe("on_register_source", function()
        local mock_source
        local get_client, try_add
        before_each(function()
            mock_source = {
                filetypes = { ["lua"] = true },
                methods = { [methods.internal.DIAGNOSTICS] = true },
                generator = {},
            }

            get_client = stub(u, "get_client")
            try_add = stub(lspconfig, "try_add")
        end)
        after_each(function()
            vim.bo.filetype = ""
            get_client:revert()
            try_add:revert()
        end)

        it("should do nothing if client does not exist", function()
            lspconfig.on_register_source(mock_source)

            assert.stub(try_add).was_not_called()
        end)

        it("should call try_add with bufnr", function()
            get_client.returns({})

            lspconfig.on_register_source(mock_source)

            assert.stub(try_add).was_called_with(vim.api.nvim_get_current_buf())
        end)

        it("should call client.notify if source is available", function()
            local mock_client = { notify = stub.new() }
            get_client.returns(mock_client)
            vim.bo.filetype = "lua"

            lspconfig.on_register_source(mock_source)

            assert.stub(mock_client.notify).was_called_with(methods.lsp.DID_CHANGE, {
                textDocument = {
                    uri = vim.uri_from_bufnr(vim.api.nvim_get_current_buf()),
                },
            })
        end)
    end)

    describe("on_register_sources", function()
        after_each(function()
            require("lspconfig")["null-ls"].filetypes = {}
        end)

        it("should update config.filetypes", function()
            c.register(require("null-ls.builtins")._test.mock_code_action)

            lspconfig.on_register_sources()

            local filetypes = require("lspconfig")["null-ls"].filetypes
            assert.equals(#filetypes, 1)
            assert.truthy(vim.tbl_contains(filetypes, "lua"))
        end)
    end)

    describe("try_add", function()
        local mock_source = {
            filetypes = { ["lua"] = true },
            methods = { [methods.internal.DIAGNOSTICS] = true },
            generator = {},
        }

        local original_manager = require("lspconfig")["null-ls"].manager
        local mock_manager = {
            try_add = stub.new(),
        }

        before_each(function()
            require("lspconfig")["null-ls"].manager = mock_manager
        end)
        after_each(function()
            require("lspconfig")["null-ls"].manager = original_manager
            mock_manager.try_add:clear()

            vim.bo.filetype = ""
            vim.bo.buftype = ""
        end)

        it("should attach if source is available and filetype matches", function()
            c._set({ _sources = { mock_source } })
            vim.bo.filetype = "lua"

            lspconfig.try_add()

            assert.stub(mock_manager.try_add).was_called_with(vim.api.nvim_get_current_buf())
        end)
    end)
end)
