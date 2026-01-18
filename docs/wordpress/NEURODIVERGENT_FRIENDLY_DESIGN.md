# Neurodivergent-Friendly Design Guide

Guide for designing an accessible trading academy website for users with ADHD, Autism (ASD), Dyslexia, and other neurodivergent conditions.

## Why This Matters

- ~15-40% of the population has neurodivergent traits
- Features designed for neurodiversity improve usability for everyone
- Inclusive design is increasingly required by law (WCAG, ADA, EAA)
- Differentiator for your trading academy

## Design Principles

### 1. Colors and Contrast

| Element | Recommendation | Reason |
|---------|----------------|--------|
| Max colors | 3 + neutrals | Prevents sensory overload |
| Background | Off-white (#F8F9FA), not pure white | Reduces eye strain |
| Text | Dark gray (#343A40), not pure black | Softer on eyes |
| Contrast ratio | 4.5:1 minimum (WCAG AA) | Ensures readability |

#### Recommended Palette (Trading Theme)

```css
/* Light Mode */
--bg-primary:      #F8F9FA;  /* Off-white (not pure white) */
--bg-secondary:    #E9ECEF;  /* Light gray */
--text-primary:    #343A40;  /* Dark gray (not pure black) */
--text-secondary:  #6C757D;  /* Medium gray */

--accent-success:  #28A745;  /* Green - Bull/Profit (muted) */
--accent-danger:   #DC3545;  /* Red - Bear/Loss (muted) */
--accent-primary:  #0D6EFD;  /* Blue - CTAs */

/* Dark Mode */
--bg-primary:      #1E1E1E;  /* Dark gray (not pure black) */
--bg-secondary:    #2D2D2D;  /* Slightly lighter */
--text-primary:    #E0E0E0;  /* Light gray (not pure white) */
--text-secondary:  #A0A0A0;  /* Medium gray */
```

### 2. Typography

| Aspect | Recommendation | Why |
|--------|----------------|-----|
| Font family | Sans-serif (Inter, Manrope, Open Sans) | Cleaner, easier to read |
| Font size | 18px minimum for body text | Reduces strain |
| Line height | 1.5-1.8 | Improves tracking |
| Letter spacing | +0.5px | Helps dyslexic readers |
| Paragraph length | 3-4 lines max | Prevents overwhelm |
| Line length | 50-75 characters | Optimal reading |

#### Dyslexia-Friendly Fonts
- OpenDyslexic (free)
- Lexie Readable
- Sylexiad

### 3. Layout and Whitespace

- **Generous whitespace** between sections ("breathing room")
- **Clear visual hierarchy** with headings (H1 → H2 → H3)
- **Consistent layout** across all pages
- **One main action** per screen/section
- **Cards with clear borders** to separate content chunks

### 4. Navigation

| Element | Implementation |
|---------|----------------|
| Menu | Consistent position on all pages |
| Breadcrumbs | Always visible (Home > Courses > Lesson 1) |
| Search | Prominent, always accessible |
| Labels | Text + icon (never icon-only) |
| Current location | Clearly highlighted |

### 5. Motion and Animations

| Rule | Implementation |
|------|----------------|
| No autoplay | Videos/animations require user action |
| Pause button | Visible on all animated content |
| Reduced motion | Respect `prefers-reduced-motion` CSS |
| No flashing | Never flash more than 3 times/second |
| Subtle transitions | Max 0.3s, ease-in-out |

```css
/* Respect user preference for reduced motion */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

### 6. Content and Language

- **Plain language** - avoid jargon, explain technical terms
- **Short sentences** - one idea per sentence
- **Bullet points** - instead of long paragraphs
- **Clear instructions** - numbered steps for tasks
- **No idioms/metaphors** - literal language preferred
- **Consistent terminology** - same word for same concept

### 7. Time and Pacing

| Feature | Implementation |
|---------|----------------|
| No time limits | Or allow extensions |
| Save progress | Auto-save frequently |
| Pause/resume | Always available |
| Speed controls | 0.5x to 2x for videos |
| No timeouts | Or warn before session expires |

## LearnDash LMS Specific

### Course Structure

```
✓ Lessons: 5-10 minutes maximum
✓ Chunks: One concept per lesson
✓ Progress: Visual progress bar always visible
✓ Checkpoints: "Did you understand? ✓" after each section
✓ Multiple formats: Video + Text + Audio for each lesson
```

### Quiz Settings

| Setting | Value | Reason |
|---------|-------|--------|
| Time limit | None or generous | Reduces anxiety |
| Attempts | Multiple (3+) | Allows learning from mistakes |
| Feedback | Immediate, specific | Helps understanding |
| Progress saving | Auto-save answers | Prevents loss |

### Video Content

- [ ] Subtitles/captions on ALL videos
- [ ] Speed control (0.5x - 2x)
- [ ] No background music (or toggle off)
- [ ] Clear audio, minimal background noise
- [ ] Chapter markers for navigation
- [ ] Transcript available

## WordPress Implementation

### Recommended Plugins

| Plugin | Purpose | Price |
|--------|---------|-------|
| [Readabler](https://readabler.com/) | ADHD mode, dyslexia fonts, reading guides | ~$29 lifetime |
| [Accessibility Assistant](https://wordpress.org/plugins/accessibility-assistant/) | Reading mask, line guide | Free/Pro |
| Ally (already installed) | Basic accessibility features | Free |

### Readabler Features

- **ADHD Mode**: Reduces distractions, highlights focus area
- **Cognitive Mode**: Simplifies interface
- **Dyslexia Font**: Switches to OpenDyslexic
- **Reading Guide**: Line-by-line highlight
- **Pause Animations**: Stops all motion
- **High Contrast**: Toggle for visibility

### Theme Settings (Astra/Elementor)

```
Typography:
- Body font: Inter or Manrope
- Base size: 18px
- Line height: 1.6
- Letter spacing: 0.5px

Colors:
- Enable dark mode toggle
- Use palette defined above

Layout:
- Content width: 1140px max
- Generous padding: 40-60px sections
```

## Implementation Checklist

### Design Base
- [ ] Palette with maximum 3 colors + neutrals
- [ ] Dark gray/off-white contrast (not pure black/white)
- [ ] Sans-serif typography (Inter or Manrope)
- [ ] Line-height minimum 1.5
- [ ] Increased letter spacing (+0.5px)

### Navigation
- [ ] Consistent menu on all pages
- [ ] Visible breadcrumbs
- [ ] Prominent search
- [ ] Clear labels (not icon-only)

### Content
- [ ] Hierarchical headings (H1 → H2 → H3)
- [ ] Short paragraphs (3-4 lines max)
- [ ] Bullet lists instead of text blocks
- [ ] Direct language, no complex metaphors

### Multimedia
- [ ] No autoplay videos
- [ ] Visible pause/stop button
- [ ] Playback speed control
- [ ] Subtitles on all videos
- [ ] Option to disable animations

### LearnDash
- [ ] Lessons max 10 minutes
- [ ] Clear visual progress
- [ ] Quizzes without time limit
- [ ] Multiple attempts allowed
- [ ] Certificates as positive reinforcement

### Accessibility Plugin
- [ ] Install Readabler or similar
- [ ] ADHD mode available
- [ ] Dyslexia font option
- [ ] Reading guide/mask
- [ ] Reduced motion toggle

## Testing

### Manual Testing
1. Navigate entire site using only keyboard
2. Use screen reader (NVDA, VoiceOver)
3. Test with browser zoom at 200%
4. Test with `prefers-reduced-motion` enabled
5. Test with high contrast mode

### Automated Tools
- [WAVE](https://wave.webaim.org/) - Accessibility evaluation
- [axe DevTools](https://www.deque.com/axe/) - Browser extension
- [Lighthouse](https://developers.google.com/web/tools/lighthouse) - Chrome DevTools

### User Testing
- Recruit neurodivergent beta testers
- Gather feedback on:
  - Cognitive load
  - Reading ease
  - Navigation clarity
  - Overall comfort

## Resources

### Guidelines
- [WCAG 2.1](https://www.w3.org/WAI/WCAG21/quickref/) - Web Content Accessibility Guidelines
- [AASPIRE Guidelines](https://www.liebertpub.com/doi/10.1089/aut.2018.0020) - Autism-specific web accessibility
- [Neurodiversity Design System](https://www.neurodiversity.design/) - Design standards

### Articles
- [Designing for Neurodiversity - Smashing Magazine](https://www.smashingmagazine.com/2025/06/designing-for-neurodiversity/)
- [Neurodiversity and UX - Stéphanie Walter](https://stephaniewalter.design/blog/neurodiversity-and-ux-essential-resources-for-cognitive-accessibility/)
- [How Inclusive Design Supports Learners on the Autism Spectrum - D2L](https://www.d2l.com/en-apac/blog/how-inclusive-design-supports-learners-on-the-autism-spectrum/)

### Fonts
- [Inter](https://fonts.google.com/specimen/Inter) - Clean, accessible sans-serif
- [Manrope](https://fonts.google.com/specimen/Manrope) - Modern, readable
- [OpenDyslexic](https://opendyslexic.org/) - Designed for dyslexia

---

*Last updated: 2025-01-18*
