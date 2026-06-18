describe("Chinese vertical EPUB rendering", function()
    local DocumentRegistry, ReaderUI, UIManager, Screen, DocSettings, Geom

    setup(function()
        require("commonrequire")
        disable_plugins()
        DocumentRegistry = require("document/documentregistry")
        ReaderUI = require("apps/reader/readerui")
        UIManager = require("ui/uimanager")
        Screen = require("device").screen
        DocSettings = require("docsettings")
        Geom = require("ui/geometry")
    end)

    local function render_vertical_epub(sample_epub, screenshot_prefix, pages, render_dpi)
        DocSettings:open(sample_epub):purge()
        local readerui = ReaderUI:new{
            dimen = Screen:getSize(),
            document = DocumentRegistry:openDocument(sample_epub),
        }
        finally(function()
            UIManager:close(readerui)
            UIManager:quit()
            readerui:onClose()
        end)
        readerui.status.enabled = false
        if render_dpi then
            readerui.document:setRenderDPI(render_dpi)
        end
        readerui.typeset:setChineseVerticalMode("on")
        UIManager:show(readerui)
        fastforward_ui_events()
        screenshot(Screen, screenshot_prefix .. "_page_1.png")
        local page_count = readerui.document:getPageCount()
        print(screenshot_prefix .. " page count: " .. page_count)
        assert.is_true(page_count >= pages)
        for page = 2, pages do
            readerui.rolling:onGotoViewRel(1)
            fastforward_ui_events()
            screenshot(Screen, screenshot_prefix .. "_page_" .. page .. ".png")
        end
    end

    local function render_vertical_epub_from_toc(sample_epub, screenshot_prefix, toc_index, pages)
        DocSettings:open(sample_epub):purge()
        local readerui = ReaderUI:new{
            dimen = Screen:getSize(),
            document = DocumentRegistry:openDocument(sample_epub),
        }
        finally(function()
            UIManager:close(readerui)
            UIManager:quit()
            readerui:onClose()
        end)
        readerui.status.enabled = false
        readerui.typeset:setChineseVerticalMode("on")
        UIManager:show(readerui)
        fastforward_ui_events()
        readerui.toc:fillToc()
        local target = readerui.toc.toc[toc_index]
        assert.is_not_nil(target)
        readerui.rolling:onGotoXPointer(target.xpointer, target.xpointer)
        fastforward_ui_events()
        screenshot(Screen, screenshot_prefix .. "_page_1.png")
        local page_count = readerui.document:getPageCount()
        print(screenshot_prefix .. " page count: " .. page_count)
        assert.is_true(page_count >= pages)
        assert.is_true(readerui.rolling.current_page <= target.page + 1)
        for page = 2, pages do
            readerui.rolling:onGotoViewRel(1)
            fastforward_ui_events()
            screenshot(Screen, screenshot_prefix .. "_page_" .. page .. ".png")
        end
    end

    it("should render multiple Chinese paragraphs in vertical mode", function()
        render_vertical_epub("spec/front/unit/data/chinese-vertical-paragraphs.epub",
            "chinese_vertical_paragraphs", 1)
    end)

    it("should auto-detect vertical writing declarations in EPUB stylesheets", function()
        local sample_epub = "spec/front/unit/data/chinese-vertical-paragraphs.epub"
        DocSettings:open(sample_epub):purge()
        local readerui = ReaderUI:new{
            dimen = Screen:getSize(),
            document = DocumentRegistry:openDocument(sample_epub),
        }
        finally(function()
            UIManager:close(readerui)
            UIManager:quit()
            readerui:onClose()
        end)
        readerui.status.enabled = false
        readerui.typeset:setChineseVerticalMode("auto")
        assert.are.same("on", readerui.typeset.chinese_vertical_effective_mode)
        assert.is_true(readerui.doc_settings:readSetting("chinese_vertical_auto_detected"))
        UIManager:show(readerui)
        fastforward_ui_events()
        screenshot(Screen, "chinese_vertical_auto_detect_page_1.png")
        assert.is_true(readerui.document:getPageCount() >= 1)
    end)

    it("should hit-test, select, and return stable highlight boxes in vertical mode", function()
        local sample_epub = "spec/front/unit/data/chinese-vertical-paragraphs.epub"
        DocSettings:open(sample_epub):purge()
        local readerui = ReaderUI:new{
            dimen = Screen:getSize(),
            document = DocumentRegistry:openDocument(sample_epub),
        }
        finally(function()
            UIManager:close(readerui)
            UIManager:quit()
            readerui:onClose()
        end)
        readerui.status.enabled = false
        readerui.typeset:setChineseVerticalMode("on")
        UIManager:show(readerui)
        fastforward_ui_events()

        local start_xp = readerui.document:getNextVisibleWordStart(readerui.document:getXPointer())
        assert.is_not_nil(start_xp)
        local end_xp = readerui.document:getNextVisibleWordEnd(start_xp)
        assert.is_not_nil(end_xp)
        local boxes = readerui.document:getScreenBoxesFromPositions(start_xp, end_xp, true)
        assert.is_true(#boxes > 0)
        for _, box in ipairs(boxes) do
            assert.is_true(box.w >= 0)
            assert.is_true(box.h >= 0)
        end

        local first_box = boxes[1]
        local hit = readerui.document:getWordFromPosition({
            x = first_box.x + first_box.w * 0.5,
            y = first_box.y + first_box.h * 0.5,
        }, true)
        assert.is_not_nil(hit)
        assert.is_not_nil(hit.sbox)
        assert.is_not_nil(hit.pos0)

        local last_box = boxes[#boxes]
        local selection = readerui.document:getTextFromPositions({
            x = first_box.x + first_box.w * 0.5,
            y = first_box.y + first_box.h * 0.5,
        }, {
            x = last_box.x + last_box.w * 0.5,
            y = last_box.y + last_box.h * 0.5,
        }, true)
        assert.is_not_nil(selection)
        assert.is_not_nil(selection.pos0)
        assert.is_true(#selection.sboxes > 0)
    end)

    it("should render one long Chinese paragraph across pages in vertical mode", function()
        render_vertical_epub("spec/front/unit/data/chinese-vertical-long-paragraph.epub",
            "chinese_vertical_long_paragraph", 4)
    end)

    it("should render ASCII punctuation as fullwidth Chinese punctuation in vertical mode", function()
        render_vertical_epub("spec/front/unit/data/chinese-vertical-punctuation.epub",
            "chinese_vertical_punctuation", 1)
    end)

    it("should keep heading background on the vertical heading block", function()
        render_vertical_epub("spec/front/unit/data/chinese-vertical-heading-background.epub",
            "chinese_vertical_heading_background", 1)
    end)

    it("should keep vertical box model backgrounds and margins stable", function()
        render_vertical_epub("spec/front/unit/data/chinese-vertical-box-model-regression.epub",
            "chinese_vertical_box_model_regression", 2)
    end)

    it("should render mixed Latin, numbers, and strict punctuation in vertical mode", function()
        render_vertical_epub("spec/front/unit/data/chinese-vertical-mixed-regression.epub",
            "chinese_vertical_mixed_regression", 1)
    end)

    it("should render the public-domain Paris Camellia Lady EPUB body pages in vertical mode", function()
        render_vertical_epub_from_toc("spec/front/unit/data/chinese-vertical-paris-camellia-lady.epub",
            "chinese_vertical_paris_camellia_lady", 4, 3)
    end)

    it("should render the public-domain Paris Camellia Lady cover image in vertical mode", function()
        render_vertical_epub("spec/front/unit/data/chinese-vertical-paris-camellia-lady.epub",
            "chinese_vertical_paris_camellia_lady_cover", 5, 212)
    end)

    it("should render logical properties, inline images, linked notes, blockquotes, and justify in vertical mode", function()
        render_vertical_epub("spec/front/unit/data/chinese-vertical-logical-interactions.epub",
            "chinese_vertical_logical_interactions", 2)
    end)

    it("should render vertical-lr, prefixed writing properties, and nested horizontal writing", function()
        render_vertical_epub("spec/front/unit/data/chinese-vertical-lr-prefixed.epub",
            "chinese_vertical_lr_prefixed", 2)
    end)

    it("should render long-term vertical text core CSS properties", function()
        render_vertical_epub("spec/front/unit/data/chinese-vertical-text-core-regression.epub",
            "chinese_vertical_text_core_regression", 2)
    end)

    it("should keep bookmarks, highlights, and dictionary lookup stable in vertical interaction smoke tests", function()
        local sample_epub = "spec/front/unit/data/chinese-vertical-logical-interactions.epub"
        DocSettings:open(sample_epub):purge()
        local readerui = ReaderUI:new{
            dimen = Screen:getSize(),
            document = DocumentRegistry:openDocument(sample_epub),
        }
        finally(function()
            UIManager:close(readerui.highlight.highlight_dialog)
            UIManager:close(readerui)
            UIManager:quit()
            readerui:onClose()
        end)
        readerui.status.enabled = false
        readerui.typeset:setChineseVerticalMode("on")
        UIManager:show(readerui)
        fastforward_ui_events()

        assert.is_true(readerui.document:isVerticalWritingMode())
        readerui.bookmark:onToggleBookmark()
        fastforward_ui_events()
        assert.is_true(readerui.view.dogear_visible)

        local start_xp = readerui.document:getNextVisibleWordStart(readerui.document:getXPointer())
        assert.is_not_nil(start_xp)
        local end_xp = readerui.document:getNextVisibleWordEnd(start_xp)
        assert.is_not_nil(end_xp)
        local boxes = readerui.document:getScreenBoxesFromPositions(start_xp, end_xp, true)
        assert.is_true(#boxes > 0)
        local first_box = boxes[1]
        local hit = readerui.document:getWordFromPosition(Geom:new{
            x = first_box.x + first_box.w * 0.5,
            y = first_box.y + first_box.h * 0.5,
        }, true)
        assert.is_not_nil(hit)
        local highlight_index = readerui.annotation:addItem{
            page = start_xp,
            pos0 = start_xp,
            pos1 = end_xp,
            text = readerui.document:getTextFromXPointers(start_xp, end_xp),
            drawer = readerui.view.highlight.saved_drawer,
            color = readerui.view.highlight.saved_color,
            chapter = readerui.toc:getTocTitleByPage(start_xp),
        }
        assert.is_true(highlight_index > 0)
        assert.is_true(#readerui.annotation.annotations >= 2)

        assert.are.same("茶花女", readerui.dictionary:cleanVerticalCJKSelection("茶 \n花　女"))
        screenshot(Screen, "chinese_vertical_interactions.png")
    end)

    it("should jump to the start of a long chapter from TOC in vertical mode", function()
        local sample_epub = "spec/front/unit/data/chinese-vertical-toc-long.epub"
        DocSettings:open(sample_epub):purge()
        local readerui = ReaderUI:new{
            dimen = Screen:getSize(),
            document = DocumentRegistry:openDocument(sample_epub),
        }
        finally(function()
            UIManager:close(readerui)
            UIManager:quit()
            readerui:onClose()
        end)
        readerui.status.enabled = false
        readerui.typeset:setChineseVerticalMode("on")
        UIManager:show(readerui)
        fastforward_ui_events()
        readerui.toc:fillToc()
        local target = readerui.toc.toc[2]
        assert.is_not_nil(target)
        assert.is_true(readerui.document:getPageCount() >= 4)
        readerui.rolling:onGotoXPointer(target.xpointer, target.xpointer)
        fastforward_ui_events()
        screenshot(Screen, "chinese_vertical_toc_jump_page.png")
        assert.is_true(readerui.rolling.current_page <= target.page + 1)
    end)
end)
