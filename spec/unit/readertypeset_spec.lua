describe("ReaderTypeset module", function()
    local ReaderTypeset

    setup(function()
        require("commonrequire")
        ReaderTypeset = require("apps/reader/modules/readertypeset")
    end)

    local function newTypeset(document, doc_settings)
        return ReaderTypeset:new{
            configurable = {},
            ui = {
                menu = {
                    registerToMainMenu = function() end,
                },
                doc_settings = doc_settings,
                document = document,
                handleEvent = function() end,
            },
        }
    end

    local function newDocSettings(initial)
        local saved = initial or {}
        return saved, {
            readSetting = function(_, key)
                return saved[key]
            end,
            saveSetting = function(_, key, value)
                saved[key] = value
            end,
            hasNot = function(_, key)
                return saved[key] == nil
            end,
        }
    end

    it("should switch Chinese vertical mode and request rerender", function()
        local writing_mode
        local text_orientation
        local update_pos_count = 0
        local typeset = ReaderTypeset:new{
            configurable = {},
            ui = {
                menu = {
                    registerToMainMenu = function() end,
                },
                document = {
                    setWritingMode = function(_, mode)
                        writing_mode = mode
                    end,
                    setTextOrientation = function(_, mode)
                        text_orientation = mode
                    end,
                },
                handleEvent = function()
                    update_pos_count = update_pos_count + 1
                end,
            },
        }

        typeset:setChineseVerticalMode("on")
        assert.are.same("on", typeset.configurable.chinese_vertical_mode)
        assert.are.same("vertical-rl", writing_mode)
        assert.are.same("mixed", text_orientation)

        typeset:setChineseVerticalMode("off")
        assert.are.same("off", typeset.configurable.chinese_vertical_mode)
        assert.are.same("horizontal-tb", writing_mode)
        assert.are.same("mixed", text_orientation)
        assert.are.same(2, update_pos_count)
    end)

    it("should auto-detect Chinese vertical mode and cache the result", function()
        local writing_mode
        local detect_count = 0
        local saved = {}
        local typeset = newTypeset({
            detectChineseVerticalMode = function()
                detect_count = detect_count + 1
                return true, "stylesheet-writing-mode"
            end,
            setWritingMode = function(_, mode)
                writing_mode = mode
            end,
            setTextOrientation = function() end,
        }, {
            readSetting = function(_, key)
                return saved[key]
            end,
            saveSetting = function(_, key, value)
                saved[key] = value
            end,
        })

        typeset:setChineseVerticalMode("auto")
        assert.are.same("auto", typeset.configurable.chinese_vertical_mode)
        assert.are.same("on", typeset.chinese_vertical_effective_mode)
        assert.are.same("vertical-rl", writing_mode)
        assert.are.same(1, detect_count)
        assert.is_true(saved.chinese_vertical_auto_detected)
        assert.are.same("stylesheet-writing-mode", saved.chinese_vertical_auto_detect_reason)

        typeset:setChineseVerticalMode("auto")
        assert.are.same(1, detect_count)
    end)

    it("should keep auto mode horizontal when detection is negative", function()
        local writing_mode
        local typeset = newTypeset({
            detectChineseVerticalMode = function()
                return false, "not-detected"
            end,
            setWritingMode = function(_, mode)
                writing_mode = mode
            end,
            setTextOrientation = function() end,
        }, {
            readSetting = function() end,
            saveSetting = function() end,
        })

        typeset:setChineseVerticalMode("auto")
        assert.are.same("off", typeset.chinese_vertical_effective_mode)
        assert.are.same("horizontal-tb", writing_mode)
    end)

    it("should default vertical page turn preference to RTL", function()
        local typeset = newTypeset({
            setWritingMode = function() end,
            setTextOrientation = function() end,
        })

        typeset:setVerticalPageTurn()
        assert.are.same("rtl", typeset.configurable.vertical_page_turn)
        typeset:setVerticalPageTurn("ltr")
        assert.are.same("ltr", typeset.configurable.vertical_page_turn)
        typeset:setVerticalPageTurn("bogus")
        assert.are.same("rtl", typeset.configurable.vertical_page_turn)
    end)

    it("should apply Chinese vertical profile defaults once without overriding existing settings", function()
        local saved, doc_settings = newDocSettings{
            hyphenation = true,
            line_spacing = 95,
        }
        local applied = {}
        local typeset = newTypeset({
            setTextMainLang = function(_, value) applied.text_lang = value end,
            setTextEmbeddedLangs = function(_, value) applied.text_lang_embedded_langs = value end,
            setTextHyphenation = function(_, value) applied.hyphenation = value end,
            setTextHyphenationSoftHyphensOnly = function(_, value) applied.hyph_soft_hyphens_only = value end,
            setTextHyphenationForceAlgorithmic = function(_, value) applied.hyph_force_algorithmic = value end,
            setCJKWidthScaling = function(_, value) applied.cjk_width_scaling = value end,
            setInterlineSpacePercent = function(_, value) applied.line_spacing = value end,
            setWordSpacing = function(_, value) applied.word_spacing = value end,
            setWordExpansion = function(_, value) applied.word_expansion = value end,
        }, doc_settings)
        typeset.configurable.hyphenation = saved.hyphenation
        typeset.configurable.line_spacing = saved.line_spacing
        typeset.chinese_vertical_effective_mode = "on"

        typeset:applyChineseVerticalProfileDefaults(doc_settings)

        assert.is_true(saved.hyphenation)
        assert.are.same(95, saved.line_spacing)
        assert.are.same("zh-Hant", saved.text_lang)
        assert.are.same(100, saved.cjk_width_scaling)
        assert.are.same({ 95, 100 }, saved.word_spacing)
        assert.is_true(saved.chinese_vertical_profile_defaults_applied)
        assert.is_true(applied.hyphenation)
        assert.are.same(95, applied.line_spacing)

        saved.hyphenation = false
        saved.line_spacing = 110
        typeset.configurable.hyphenation = false
        typeset.configurable.line_spacing = 110
        typeset:applyChineseVerticalProfileDefaults(doc_settings)
        assert.is_false(saved.hyphenation)
        assert.are.same(110, saved.line_spacing)
    end)

    it("should disable hyphenation by default for new Chinese vertical documents", function()
        local saved, doc_settings = newDocSettings()
        local applied = {}
        local typeset = newTypeset({
            setTextMainLang = function() end,
            setTextEmbeddedLangs = function() end,
            setTextHyphenation = function(_, value) applied.hyphenation = value end,
            setTextHyphenationSoftHyphensOnly = function() end,
            setTextHyphenationForceAlgorithmic = function() end,
            setCJKWidthScaling = function() end,
            setInterlineSpacePercent = function() end,
            setWordSpacing = function() end,
            setWordExpansion = function() end,
        }, doc_settings)
        typeset.chinese_vertical_effective_mode = "on"

        typeset:applyChineseVerticalProfileDefaults(doc_settings)

        assert.is_false(saved.hyphenation)
        assert.is_false(applied.hyphenation)
        assert.are.same("zh-Hant", saved.text_lang)
        assert.are.same(110, saved.line_spacing)
    end)
end)
