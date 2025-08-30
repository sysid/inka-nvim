# Complex Inka2 Test Cases

This file tests more complex scenarios with inka2 cards.

---

Deck: Complex Examples

Tags: complex testing edge-cases

1. Question with code in the answer?

> Here's some code:
> ```python
> def hello():
>     print("Hello, World!")
> ```
> This should be preserved properly.

<!--ID:2001001001-->
2. Question with nested markdown formatting?

> Answer with **bold** and *italic* text
> 
> - List item 1
> - List item 2
>   - Nested item
> 
> And a [link](https://example.com)

3. Question followed by empty line?

> This answer is followed by empty lines
> 


4. Adjacent question after empty lines?

> Answer to adjacent question

<!--ID:3001001001-->
5. Question with mixed indentation in question text?

  Additional context line
    More context with different indentation

> Answer with consistent formatting
> Second line of answer

6. Question with mathematical notation: What is $\\sum_{i=1}^n i$?

> The formula is: $\\frac{n(n+1)}{2}$
> For example, when n=5: $\\frac{5 \\cdot 6}{2} = 15$

---

Text between sections.

---

Deck: Edge Cases

Tags: edge-cases

7. Question at very end of section?

> Final answer in section

---