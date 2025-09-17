pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtCore
import Quickshell
import Quickshell.Io
import org.kde.sonnet as Sonnet
import qs.Common

Singleton {
    id: root

    // Properties for configuration
    property bool enabled: SettingsData.spellcheckEnabled
    property string currentLanguage: SettingsData.spellcheckLanguage || "en_US"
    property bool automaticLanguageDetection: SettingsData.spellcheckAutoDetectLanguage
    property color misspelledColor: SettingsData.spellcheckHighlightColor || Theme.error

    // Internal properties

    property var activeHighlighters: ({})
    property var contextMenus: ({})
    property var textAreaStates: ({}) // Track state of each textarea
    property bool globalCursorUpdateEnabled: true
    property QtObject currentTextArea: null
    property var ignoredWords: []
    property var settingsModalRef: null
    
    // Storage paths - use same location as notepad files
    readonly property string storageDir: StandardPaths.writableLocation(StandardPaths.GenericStateLocation) + "/DankMaterialShell"
    readonly property string dictionaryPath: storageDir + "/spellcheck-dictionary.json"
    readonly property string ignoredWordsPath: storageDir + "/spellcheck-ignored.json"
    property string lastKnownText: ""
    property bool isDeletionOperation: false
    
    // Custom dictionary management
    property var customDictionary: []
    
    signal spellcheckEnabledChanged()
    signal languageChanged()

    // Create a spellcheck highlighter for a given TextArea
    function createHighlighter(textArea) {
        if (!textArea || !textArea.textDocument) {
            console.warn("SpellcheckService: Invalid TextArea provided")
            return null
        }

        var textAreaId = generateTextAreaId(textArea)
        
        // Clean up existing highlighter if it exists
        if (activeHighlighters[textAreaId]) {
            destroyHighlighter(textAreaId)
        }

        // Validate cursor position and selection bounds before creating highlighter
        var textLength = textArea.text ? textArea.text.length : 0
        
        // For Sonnet, use ultra-conservative cursor positioning
        var safeCursorPosition = textArea.cursorPosition
        if (textLength > 0) {
            safeCursorPosition = Math.max(0, Math.min(textArea.cursorPosition, textLength - 1))
        } else {
            safeCursorPosition = 0
        }
        
        var safeSelectionStart = Math.max(0, Math.min(textArea.selectionStart, Math.max(0, textLength - 1)))
        var safeSelectionEnd = Math.max(0, Math.min(textArea.selectionEnd, Math.max(0, textLength - 1)))

        var highlighter = highlighterComponent.createObject(root, {
            document: textArea.textDocument,
            cursorPosition: safeCursorPosition,
            selectionStart: safeSelectionStart,
            selectionEnd: safeSelectionEnd,
            active: root.enabled,
            currentLanguage: root.currentLanguage,
            misspelledColor: root.misspelledColor,
            autoDetectLanguageDisabled: !root.automaticLanguageDetection
        })

        if (!highlighter) {
            console.error("SpellcheckService: Failed to create highlighter")
            return null
        }

        // Store the highlighter
        activeHighlighters[textAreaId] = highlighter

        // Connect to TextArea property changes
        connectTextAreaProperties(textArea, highlighter)

        // Connect to cursor position changes using official Sonnet pattern
        highlighter.changeCursorPosition.connect(function(start, end) {
            // Check if cursor updates are globally disabled
            if (!root.globalCursorUpdateEnabled) {
                console.log("SpellcheckService: Cursor update disabled, ignoring position change")
                return
            }
            
            // Validate TextArea and document state
            if (!textArea || !textArea.textDocument) {
                console.warn("SpellcheckService: TextArea or textDocument is null/undefined")
                return
            }
            
            var textLength = textArea.text ? textArea.text.length : 0
            
            // Strict bounds checking - reject completely invalid positions
            if (start < 0 || start > textLength || end < 0 || end > textLength) {
                console.warn("SpellcheckService: Cursor position out of bounds, rejecting. start:", start, "end:", end, "textLength:", textLength)
                return
            }
            
            // Official Sonnet pattern: direct cursor positioning with bounds validation
            Qt.callLater(() => {
                if (!textArea || !textArea.textDocument || !root.globalCursorUpdateEnabled) return
                
                // Re-validate bounds in case text changed
                var currentTextLength = textArea.text ? textArea.text.length : 0
                if (start > currentTextLength || end > currentTextLength) {
                    console.warn("SpellcheckService: Text changed during cursor update, positions now invalid")
                    return
                }
                
                try {
                    // Apply cursor positioning using official Sonnet pattern
                    textArea.cursorPosition = start
                    if (start !== end) {
                        textArea.moveCursorSelection(end, TextEdit.SelectCharacters)
                    }
                } catch (error) {
                    console.warn("SpellcheckService: Error in cursor positioning:", error)
                }
            })
        })

        return highlighter
    }

    // Destroy a highlighter for a given TextArea
    function destroyHighlighter(textAreaOrId) {
        var textAreaId = typeof textAreaOrId === 'string' ? textAreaOrId : generateTextAreaId(textAreaOrId)
        
        if (activeHighlighters[textAreaId]) {
            activeHighlighters[textAreaId].destroy()
            delete activeHighlighters[textAreaId]
        }

        if (contextMenus[textAreaId]) {
            contextMenus[textAreaId].destroy()
            delete contextMenus[textAreaId]
        }
    }

    // Get suggestions for a word at a position
    function getSuggestions(textArea, position, maxSuggestions) {
        maxSuggestions = maxSuggestions || 5
        
        if (!textArea || !textArea.text) {
            console.warn("SpellcheckService: Invalid textArea in getSuggestions")
            return []
        }
        
        var textAreaId = generateTextAreaId(textArea)
        var highlighter = activeHighlighters[textAreaId]
        
        if (!highlighter) {
            return []
        }

        // Add comprehensive bounds checking for position
        var textLength = textArea.text.length
        if (position < 0 || position > textLength) {
            console.warn("SpellcheckService: Position out of bounds in getSuggestions:", position, "textLength:", textLength)
            return []
        }
        
        var safePosition = Math.max(0, Math.min(position, textLength))

        try {
            return highlighter.suggestions(safePosition, maxSuggestions)
        } catch (error) {
            console.error("SpellcheckService: Error getting suggestions:", error)
            return []
        }
    }

    // Check if a word is misspelled
    function isWordMisspelled(textArea) {
        var textAreaId = generateTextAreaId(textArea)
        var highlighter = activeHighlighters[textAreaId]
        
        if (!highlighter) {
            return false
        }

        return highlighter.wordIsMisspelled
    }

    // Get word under cursor/mouse
    function getWordUnderMouse(textArea) {
        var textAreaId = generateTextAreaId(textArea)
        var highlighter = activeHighlighters[textAreaId]
        
        if (!highlighter) {
            return ""
        }

        return highlighter.wordUnderMouse
    }

    // Create context menu for spellcheck suggestions
    function createContextMenu(textArea, position, parentItem) {
        console.log("SpellcheckService: createContextMenu called with position:", position)
        
        if (!textArea || !textArea.text) {
            console.warn("SpellcheckService: Invalid textArea in createContextMenu")
            return null
        }
        
        var textAreaId = generateTextAreaId(textArea)
        var highlighter = activeHighlighters[textAreaId]
        
        if (!highlighter) {
            console.warn("SpellcheckService: No highlighter found for TextArea")
            return null
        }

        // Add comprehensive bounds checking for position
        var textLength = textArea.text.length
        if (position < 0 || position > textLength) {
            console.warn("SpellcheckService: Position out of bounds in createContextMenu:", position, "textLength:", textLength)
            return null
        }
        
        var safePosition = Math.max(0, Math.min(position, textLength))

        // Clean up existing context menu
        if (contextMenus[textAreaId]) {
            contextMenus[textAreaId].destroy()
        }

        var suggestions = highlighter.suggestions(safePosition, 8)
        var wordUnderCursor = highlighter.wordUnderMouse
        var isWordMisspelled = highlighter.wordIsMisspelled
        
        // Check if word is in custom dictionary or ignored words
        if (wordUnderCursor && (isWordInCustomDictionary(wordUnderCursor) || isWordIgnored(wordUnderCursor))) {
            isWordMisspelled = false
        }
        
        console.log("SpellcheckService: wordUnderCursor:", wordUnderCursor, "isWordMisspelled:", isWordMisspelled, "suggestions:", suggestions.length)

        if (!isWordMisspelled || !wordUnderCursor) {
            console.log("SpellcheckService: Word not misspelled or no word found")
            return null
        }

        // Use the provided parent or fall back to textArea
        var menuParent = parentItem || textArea
        
        var contextMenu = contextMenuComponent.createObject(menuParent, {
            textArea: textArea,
            highlighter: highlighter,
            word: wordUnderCursor,
            suggestions: suggestions,
            position: safePosition
        })

        if (!contextMenu) {
            console.error("SpellcheckService: Failed to create context menu")
            return null
        }

        contextMenus[textAreaId] = contextMenu
        console.log("SpellcheckService: Context menu created successfully with parent:", menuParent)
        return contextMenu
    }

    // Update all active highlighters when settings change
    function updateAllHighlighters() {
        for (var textAreaId in activeHighlighters) {
            var highlighter = activeHighlighters[textAreaId]
            if (highlighter) {
                highlighter.active = root.enabled
                highlighter.currentLanguage = root.currentLanguage
                highlighter.misspelledColor = root.misspelledColor
                highlighter.autoDetectLanguageDisabled = !root.automaticLanguageDetection
            }
        }
    }

    // Set global spell checking enabled/disabled
    function setEnabled(enabled) {
        if (root.enabled !== enabled) {
            SettingsData.setSpellcheckEnabled(enabled)
            // updateAllHighlighters() called by onSpellcheckEnabledChanged()
            spellcheckEnabledChanged()
        }
    }

    // Set global language
    function setLanguage(language) {
        if (root.currentLanguage !== language) {
            SettingsData.setSpellcheckLanguage(language)
            // updateAllHighlighters() called by onSpellcheckLanguageChanged()
            languageChanged()
        }
    }

    // Set automatic language detection
    function setAutomaticLanguageDetection(enabled) {
        if (root.automaticLanguageDetection !== enabled) {
            SettingsData.setSpellcheckAutoDetectLanguage(enabled)
            // updateAllHighlighters() called by onSpellcheckAutoDetectLanguageChanged()
        }
    }

    // Temporarily disable cursor position updates (for use during text operations)
    function temporarilyDisableCursorUpdates(duration = 500) {
        root.globalCursorUpdateEnabled = false
        Qt.callLater(() => {
            console.log("SpellcheckService: Disabling cursor updates for", duration, "ms")
            var timer = Qt.createQmlObject('import QtQuick; Timer { interval: ' + duration + '; running: true; repeat: false }', root, "SpellcheckTimer")
            timer.triggered.connect(() => {
                root.globalCursorUpdateEnabled = true
                console.log("SpellcheckService: Re-enabling cursor updates")
                timer.destroy()
            })
        })
    }

    // Temporarily disable all highlighters during text operations
    function temporarilyDisableHighlighters(duration = 300) {
        console.log("SpellcheckService: Temporarily disabling all highlighters for", duration, "ms")
        
        // Disable all active highlighters
        for (var textAreaId in activeHighlighters) {
            if (activeHighlighters[textAreaId]) {
                activeHighlighters[textAreaId].active = false
            }
        }
        
        // Re-enable after duration
        Qt.callLater(() => {
            var timer = Qt.createQmlObject('import QtQuick; Timer { interval: ' + duration + '; running: true; repeat: false }', root, "HighlighterTimer")
            timer.triggered.connect(() => {
                console.log("SpellcheckService: Re-enabling all highlighters")
                for (var textAreaId in activeHighlighters) {
                    if (activeHighlighters[textAreaId]) {
                        activeHighlighters[textAreaId].active = root.enabled
                    }
                }
                timer.destroy()
            })
        })
    }

    // Helper functions
    function generateTextAreaId(textArea) {
        // Use object identifier as unique ID
        if (!textArea) {
            console.warn("SpellcheckService: generateTextAreaId called with null textArea")
            return "invalid_textarea_" + Date.now()
        }
        try {
            return textArea.toString()
        } catch (error) {
            console.warn("SpellcheckService: Error generating textArea ID:", error)
            return "error_textarea_" + Date.now()
        }
    }

    function connectTextAreaProperties(textArea, highlighter) {
        // Store the initial text for deletion detection
        root.lastKnownText = textArea.text || ""
        
        // Monitor text changes for deletion detection and cursor validation
        textArea.textChanged.connect(function() {
            if (!textArea || !highlighter) return
            
            var newText = textArea.text || ""
            var newLength = newText.length
            var wasDeleted = newLength < root.lastKnownText.length
            
            // Immediate cursor position validation after text changes
            if (textArea.cursorPosition > newLength) {
                console.warn("SpellcheckService: Fixing cursor position after text change:", textArea.cursorPosition, "->", newLength)
                textArea.cursorPosition = newLength
            }
            
            if (wasDeleted) {
                console.log("SpellcheckService: Deletion detected, temporarily disabling highlighter")
                root.isDeletionOperation = true
                // Temporarily disable the highlighter during deletion operations
                highlighter.active = false
                
                // Re-enable after a brief delay to allow cursor operations to complete
                Qt.callLater(() => {
                    Qt.callLater(() => {
                        if (highlighter && root.enabled) {
                            console.log("SpellcheckService: Re-enabling highlighter after deletion")
                            highlighter.active = true
                            root.isDeletionOperation = false
                        }
                    })
                })
            } else {
                // For non-deletion changes, also ensure highlighter cursor position is valid
                if (highlighter.cursorPosition > newLength) {
                    console.warn("SpellcheckService: Fixing highlighter cursor position after text change:", highlighter.cursorPosition, "->", newLength)
                    try {
                        highlighter.cursorPosition = newLength
                    } catch (error) {
                        console.warn("SpellcheckService: Error fixing highlighter cursor position:", error)
                    }
                }
            }
            
            root.lastKnownText = newText
        })
        
        // Connect cursor position changes with robust bounds checking
        textArea.cursorPositionChanged.connect(function() {
            if (!textArea || !textArea.text || !highlighter) {
                return
            }
            
            // Skip cursor updates during deletion operations to prevent Qt internal errors
            if (root.isDeletionOperation) {
                console.log("SpellcheckService: Skipping cursor update during deletion operation")
                return
            }
            
            var textLength = textArea.text.length
            var currentCursorPos = textArea.cursorPosition
            
            // Strict validation before updating highlighter cursor position
            if (textLength <= 0) {
                // Don't update highlighter if text is empty/invalid
                return
            }
            
            // Ultra-defensive cursor position validation
            // Qt allows cursor position == textLength, but Sonnet might not
            if (currentCursorPos < 0) {
                console.warn("SpellcheckService: Negative cursor position detected:", currentCursorPos)
                return
            }
            
            if (currentCursorPos > textLength) {
                console.warn("SpellcheckService: Cursor position beyond text length:", currentCursorPos, "textLength:", textLength)
                // Fix the TextArea cursor position immediately
                var fixedPos = Math.min(currentCursorPos, textLength)
                Qt.callLater(() => {
                    if (textArea && textArea.text) {
                        textArea.cursorPosition = fixedPos
                    }
                })
                return
            }
            
            // For Sonnet, use strict bounds (position < textLength for non-empty text)
            var sonnetSafePos = currentCursorPos
            if (textLength > 0 && currentCursorPos >= textLength) {
                sonnetSafePos = textLength - 1
                console.log("SpellcheckService: Adjusting cursor position for Sonnet:", currentCursorPos, "->", sonnetSafePos)
            }
            
            try {
                highlighter.cursorPosition = sonnetSafePos
            } catch (error) {
                console.warn("SpellcheckService: Error setting highlighter cursorPosition to", sonnetSafePos, ":", error)
            }
        })

        textArea.selectionStartChanged.connect(function() {
            if (!textArea || !highlighter || !textArea.text) return
            
            // Skip selection updates during deletion operations
            if (root.isDeletionOperation) {
                console.log("SpellcheckService: Skipping selectionStart update during deletion operation")
                return
            }
            
            var textLength = textArea.text.length
            if (textLength <= 0) return
            
            var selStart = textArea.selectionStart
            var safeSelStart = Math.max(0, Math.min(selStart, textLength))
            
            try {
                highlighter.selectionStart = safeSelStart
            } catch (error) {
                console.warn("SpellcheckService: Error setting highlighter selectionStart:", error)
            }
        })

        textArea.selectionEndChanged.connect(function() {
            if (!textArea || !highlighter || !textArea.text) return
            
            // Skip selection updates during deletion operations
            if (root.isDeletionOperation) {
                console.log("SpellcheckService: Skipping selectionEnd update during deletion operation")
                return
            }
            
            var textLength = textArea.text.length
            if (textLength <= 0) return
            
            var selEnd = textArea.selectionEnd
            var safeSelEnd = Math.max(0, Math.min(selEnd, textLength))
            
            try {
                highlighter.selectionEnd = safeSelEnd
            } catch (error) {
                console.warn("SpellcheckService: Error setting highlighter selectionEnd:", error)
            }
        })
    }

    // Custom dictionary management functions
    function loadCustomDictionary() {
        try {
            var savedDict = dictionaryFile.text() || "[]"
            root.customDictionary = JSON.parse(savedDict)
            console.log("SpellcheckService: Loaded", root.customDictionary.length, "custom dictionary words from", root.dictionaryPath)
        } catch (e) {
            console.log("SpellcheckService: No dictionary file found or parse error, starting with empty dictionary:", e)
            root.customDictionary = []
        }
    }
    
    function saveCustomDictionary() {
        try {
            var jsonString = JSON.stringify(root.customDictionary, null, 2)
            dictionaryFile.setText(jsonString)
            console.log("SpellcheckService: Saved", root.customDictionary.length, "words to custom dictionary at", root.dictionaryPath)
        } catch (e) {
            console.error("SpellcheckService: Failed to save custom dictionary:", e)
        }
    }
    
    function addWordToDictionary(word) {
        if (!word || typeof word !== 'string') {
            console.warn("SpellcheckService: Invalid word for dictionary:", word)
            return false
        }
        
        var cleanWord = word.trim().toLowerCase()
        if (root.customDictionary.indexOf(cleanWord) === -1) {
            root.customDictionary.push(cleanWord)
            saveCustomDictionary()
            console.log("SpellcheckService: Added word to custom dictionary:", cleanWord)
            
            // Note: Highlighting will update on next spell check
            return true
        } else {
            console.log("SpellcheckService: Word already in custom dictionary:", cleanWord)
            return false
        }
    }
    
    function loadIgnoredWords() {
        try {
            var savedIgnored = ignoredWordsFile.text() || "[]"
            root.ignoredWords = JSON.parse(savedIgnored)
            console.log("SpellcheckService: Loaded", root.ignoredWords.length, "ignored words from", root.ignoredWordsPath)
        } catch (e) {
            console.log("SpellcheckService: No ignored words file found or parse error, starting with empty list:", e)
            root.ignoredWords = []
        }
    }
    
    function saveIgnoredWords() {
        try {
            var jsonString = JSON.stringify(root.ignoredWords, null, 2)
            ignoredWordsFile.setText(jsonString)
            console.log("SpellcheckService: Saved", root.ignoredWords.length, "ignored words to", root.ignoredWordsPath)
        } catch (e) {
            console.error("SpellcheckService: Failed to save ignored words:", e)
        }
    }
    
    function ignoreWord(word) {
        if (!word || typeof word !== 'string') {
            console.warn("SpellcheckService: Invalid word to ignore:", word)
            return false
        }
        
        var cleanWord = word.trim().toLowerCase()
        if (root.ignoredWords.indexOf(cleanWord) === -1) {
            root.ignoredWords.push(cleanWord)
            saveIgnoredWords()
            console.log("SpellcheckService: Ignored word:", cleanWord)
            
            // Note: Highlighting will update on next spell check
            return true
        } else {
            console.log("SpellcheckService: Word already ignored:", cleanWord)
            return false
        }
    }
    
    function isWordInCustomDictionary(word) {
        if (!word || typeof word !== 'string') return false
        return root.customDictionary.indexOf(word.trim().toLowerCase()) !== -1
    }
    
    function isWordIgnored(word) {
        if (!word || typeof word !== 'string') return false
        return root.ignoredWords.indexOf(word.trim().toLowerCase()) !== -1
    }
    
    function refreshSpellcheck() {
        // Force refresh of all active highlighters using a safer method
        for (var textAreaId in root.activeHighlighters) {
            var highlighter = root.activeHighlighters[textAreaId]
            if (highlighter && highlighter.rehighlight && typeof highlighter.rehighlight === 'function') {
                // Use the proper rehighlight method if available
                highlighter.rehighlight()
            } else if (highlighter && highlighter.document) {
                // Fallback: trigger a text change to force rehighlight
                var doc = highlighter.document
                if (doc && doc.modified !== undefined) {
                    var originalModified = doc.modified
                    doc.modified = !originalModified
                    doc.modified = originalModified
                }
            }
        }
        console.log("SpellcheckService: Refreshed", Object.keys(root.activeHighlighters).length, "highlighters")
    }

    // React to settings changes
    Connections {
        target: SettingsData
        function onSpellcheckEnabledChanged() {
            updateAllHighlighters()
            spellcheckEnabledChanged()
        }
        
        function onSpellcheckLanguageChanged() {
            updateAllHighlighters()
            languageChanged()
        }
        
        function onSpellcheckAutoDetectLanguageChanged() {
            updateAllHighlighters()
        }
        
        function onSpellcheckHighlightColorChanged() {
            updateAllHighlighters()
        }
    }

    // Component for creating spellcheck highlighters
    Component {
        id: highlighterComponent
        
        Sonnet.SpellcheckHighlighter {
            id: highlighter
            
            // Default properties will be set when creating
            active: root.enabled
            automatic: true
            misspelledColor: root.misspelledColor
            
            // Add bounds checking to internal operations
            property int _lastValidCursorPosition: 0
            property int _lastValidTextLength: 0
            
            // Monitor document changes for text length tracking
            onDocumentChanged: {
                if (document && document.textDocument) {
                    _lastValidTextLength = document.textDocument.plainText ? document.textDocument.plainText.length : 0
                }
            }
            
            // Override cursor position updates to add bounds checking
            onCursorPositionChanged: {
                if (document && document.textDocument) {
                    var textLength = document.textDocument.plainText ? document.textDocument.plainText.length : 0
                    
                    // Update our tracking of valid text length
                    _lastValidTextLength = textLength
                    
                    if (cursorPosition > textLength || cursorPosition < 0) {
                        console.warn("SpellcheckService: Highlighter cursor position out of bounds:", cursorPosition, "textLength:", textLength)
                        
                        // Store valid position and defer correction to avoid recursion
                        var safeCursorPos = Math.max(0, Math.min(cursorPosition, textLength))
                        _lastValidCursorPosition = safeCursorPos
                        
                        // Defer the correction to avoid interfering with ongoing operations
                        Qt.callLater(() => {
                            if (document && document.textDocument) {
                                var currentTextLength = document.textDocument.plainText ? document.textDocument.plainText.length : 0
                                var finalSafePos = Math.max(0, Math.min(_lastValidCursorPosition, currentTextLength))
                                if (finalSafePos !== cursorPosition && finalSafePos <= currentTextLength) {
                                    try {
                                        cursorPosition = finalSafePos
                                    } catch (error) {
                                        console.warn("SpellcheckService: Could not correct highlighter cursor position:", error)
                                    }
                                }
                            }
                        })
                    } else {
                        _lastValidCursorPosition = cursorPosition
                    }
                }
            }
            
            onActiveChanged: function(description) {
                if (description) {
                    console.log("SpellcheckService:", description)
                }
            }
        }
    }

    // Component for creating context menus
    Component {
        id: contextMenuComponent
        
        Menu {
            id: contextMenu
            
            property var textArea
            property var highlighter  
            property string word
            property var suggestions
            property int position
            
            // Add suggestion items
            Repeater {
                model: contextMenu.suggestions
                delegate: MenuItem {
                    required property string modelData
                    text: modelData
                    onTriggered: {
                        // Replace the misspelled word with the suggestion
                        replaceWordAtPosition(contextMenu.textArea, contextMenu.position, contextMenu.word, modelData)
                        contextMenu.close()
                    }
                }
            }
            
            MenuSeparator {
                visible: contextMenu.suggestions.length > 0
            }
            
            MenuItem {
                text: qsTr("Ignore")
                onTriggered: {
                    console.log("SpellcheckService: Ignoring word:", contextMenu.word)
                    root.ignoreWord(contextMenu.word)
                    contextMenu.close()
                }
            }
            
            MenuItem {
                text: qsTr("Add to Dictionary")
                onTriggered: {
                    var success = root.addWordToDictionary(contextMenu.word)
                    if (success) {
                        console.log("SpellcheckService: Successfully added '" + contextMenu.word + "' to custom dictionary")
                        // Force re-highlighting to update the display
                        if (contextMenu.highlighter) {
                            contextMenu.highlighter.active = false
                            Qt.callLater(() => {
                                contextMenu.highlighter.active = true
                            })
                        }
                    }
                    contextMenu.close()
                }
            }
            
            MenuSeparator {}
            
            MenuItem {
                text: qsTr("Spell Check Settings...")
                onTriggered: {
                    // Use the settingsModalRef if available, otherwise try to find it
                    var settingsModal = root.settingsModalRef || findSettingsModal()
                    if (settingsModal) {
                        settingsModal.show()
                        console.log("SpellcheckService: Opened settings modal")
                    } else {
                        console.warn("SpellcheckService: Settings modal not available")
                    }
                    if (contextMenu && contextMenu.close) {
                        contextMenu.close()
                    }
                }
            }

            function replaceWordAtPosition(textArea, pos, oldWord, newWord) {
                // Add comprehensive bounds checking for position
                if (!textArea || !textArea.text) {
                    console.warn("SpellcheckService: Invalid textArea in replaceWordAtPosition")
                    return
                }
                
                var text = textArea.text
                if (pos < 0 || pos >= text.length) {
                    console.warn("SpellcheckService: Position out of bounds in replaceWordAtPosition:", pos, "textLength:", text.length)
                    return // Position is out of bounds
                }
                
                var startPos = pos
                var endPos = pos
                
                // Find word start with bounds checking
                while (startPos > 0 && startPos < text.length && text[startPos - 1].match(/\w/)) {
                    startPos--
                }
                
                // Find word end with bounds checking
                while (endPos < text.length && text[endPos].match(/\w/)) {
                    endPos++
                }
                
                // Additional safety checks
                if (startPos < 0) startPos = 0
                if (endPos > text.length) endPos = text.length
                if (startPos >= endPos) return
                
                // Verify this is the word we expect
                var foundWord = text.substring(startPos, endPos)
                if (foundWord === oldWord) {
                    // Replace the word
                    var newText = text.substring(0, startPos) + newWord + text.substring(endPos)
                    textArea.text = newText
                    
                    // Set cursor position with robust bounds checking
                    var newCursorPos = startPos + newWord.length
                    var finalTextLength = textArea.text.length
                    var safeCursorPos = Math.max(0, Math.min(newCursorPos, finalTextLength))
                    
                    // Use Qt.callLater to avoid potential timing issues
                    Qt.callLater(function() {
                        if (textArea && textArea.text) {
                            textArea.cursorPosition = Math.min(safeCursorPos, textArea.text.length)
                        }
                    })
                }
            }
        }
    }
    
    function findSettingsModal() {
        // Search for settingsModal in the application
        try {
            // Try to access through the Application object
            if (typeof Application !== 'undefined' && Application.windows) {
                for (var i = 0; i < Application.windows.length; i++) {
                    var window = Application.windows[i]
                    if (window && window.findChild && typeof window.findChild === 'function') {
                        var modal = window.findChild("settingsModal")
                        if (modal) return modal
                    }
                }
            }
        } catch (e) {
            console.warn("SpellcheckService: Error searching for settings modal:", e)
        }
        return null
    }
    
    // File storage for custom dictionary
    FileView {
        id: dictionaryFile
        path: root.dictionaryPath 
        blockLoading: false
        blockWrites: false
    }
    
    // File storage for ignored words
    FileView {
        id: ignoredWordsFile
        path: root.ignoredWordsPath
        blockLoading: false
        blockWrites: false
    }
    
    // Ensure storage directory exists
    Component.onCompleted: {
        // Create directory if it doesn't exist
        ensureDirectoryProcess.running = true
    }
    
    Process {
        id: ensureDirectoryProcess
        command: ["mkdir", "-p", root.storageDir]
        onExited: {
            loadCustomDictionary()
            loadIgnoredWords()
        }
    }
}