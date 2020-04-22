local class = require('opus.class')
local UI    = require('opus.ui')

UI.Question = class(UI.MiniSlideOut)
UI.Question.defaults = {
    UIElement = 'Question',
    accelerators = {
        y = 'question_yes',
        n = 'question_no',
    }
}
function UI.Question:postInit()
    local x = self.label and #self.label + 3 or 1

    self.yes_button = UI.Button {
        x = x,
        text = 'Yes',
        backgroundColor = 'primary',
        event = 'question_yes',
    }
    self.no_button = UI.Button {
        x = x + 5,
        text = 'No',
        backgroundColor = 'primary',
        event = 'question_no',
    }
end
