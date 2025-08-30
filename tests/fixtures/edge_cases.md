# Edge Cases for Inka2 Testing

This file contains edge cases that might break the plugin.

---

Deck: Edge Cases

Tags: edge-cases malformed

1. Question without answer?

2. Another question immediately following?

> This is the answer to question 2

3. Question with answer but then empty section?

> Answer here

---

Empty section between:

---

Deck: Malformed Content

4. Question in the middle of nowhere - not in proper section

> This shouldn't be processed

---

Deck: Boundary Tests

5. Question at the very start of section?

> First answer

6. Question with very long content that might exceed typical line length limits and potentially cause issues with string processing or buffer manipulation in the plugin code?

> Very long answer that also exceeds typical line length limits and contains lots of text that might test the robustness of the marker insertion and removal logic when dealing with lengthy content

---

Normal text with --- that shouldn't be confused with section markers:

This line has --- dashes but not at start of line.

---

Deck: Final Tests

<!--ID:999999999-->
7. Last question with ID?

> Last answer

---