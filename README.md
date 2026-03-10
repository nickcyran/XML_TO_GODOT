# XML → Godot Renderer

Runtime renderer that converts plain XML files into Godot `Control` trees. Works on desktop and web exports.

## Usage

Structure your site folder:
```
my_site/
├── index.xml
├── about.xml
└── assets/
    └── banner.png
```

Run the project, click **Upload Site Folder…**, and select the folder. `index.xml` (or the first `.xml` found) is rendered immediately.

## Tags

| Tag | Output | Notes |
|---|---|---|
| `<page>` | `ScrollContainer` | Required root element |
| `<vbox>` | `VBoxContainer` | Vertical stack |
| `<hbox>` | `HBoxContainer` | Horizontal stack |
| `<h1>`–`<h6>` | `Label` | Sizes 32→16 px |
| `<p>` | `Label` | Wrapping body text |
| `<a href="…">` | `RichTextLabel` | Underlined, clickable |
| `<img src="…">` | `TextureRect` | Resolved from `assets/` |
| `<hr/>` | `ColorRect` | 1 px hairline rule |

## Attributes

| Attribute | Example | Effect |
|---|---|---|
| `padding` | `"16,32"` | Margin — 1, 2, or 4 values (CSS shorthand) |
| `gap` | `"12"` | Child spacing (`vbox`/`hbox` only) |
| `grow` | `"true"` | `SIZE_EXPAND_FILL` horizontally |
| `align` | `"center"` | `left` / `center` / `right` / `fill` |
| `width` / `height` | `"200"` | Fixed pixel size |
| `color` | `"#374151"` | Text color |
| `bg` | `"#1e293b"` | Background fill |

## Routing

Use `site://` links to navigate between pages. The key is the filename without `.xml`.

```xml
<a href="site://about">About</a>
<a href="site://index">← Home</a>
```

External `http(s)://` links open in the system browser.

## Template Variables

Resolved at render time inside any text content.

`@date` · `@time` · `@year` · `@month` · `@day` · `@datetime`

```xml
<p color="#6b7280">@date</p>
<p align="center">© @year My Site</p>
```

## Example Page

```xml
<page>
  <hbox gap="16" padding="16,32" bg="#1e293b">
    <h3 grow="true" color="#f1f5f9">My Site</h3>
    <a href="site://about">About</a>
  </hbox>

  <vbox gap="20" padding="32,64">
    <h1>Hello</h1>
    <hbox gap="8">
      <p color="#6b7280">By Author</p>
      <p color="#6b7280">· @date</p>
    </hbox>
    <hr/>
    <p>Content goes here.</p>
    <vbox gap="6" padding="4,20" bg="#f1f5f9">
      <p>• Item one</p>
      <p>• Item two</p>
    </vbox>
    <a href="site://about">Read more →</a>
  </vbox>

  <vbox padding="16,32" gap="4" bg="#f1f5f9">
    <hr/>
    <p align="center" color="#6b7280">My Site · @year</p>
  </vbox>
</page>
```