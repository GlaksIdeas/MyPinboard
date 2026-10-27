# Pinboard profile format (v1)

How a profile is exchanged between people and between platforms (iOS today; a website and an Android
app later). The Swift source of truth is `Models/Snapshots.swift` and `Services/ProfileLink.swift`.

There are two ways to share a profile:

| | Carries | Size | Use |
|---|---|---|---|
| **Profile file** (`.pinprofile`) | Everything: boards, pins, photos | Large (photos) | AirDrop, Messages, email |
| **Friend link** (`pinboard://friend?...`) | A name card only | Under ~5 KB | Backup when a file can't be sent |

A link can't hold a whole profile: pin photos make profiles far too large for a URL. Once there is a
server, a link will point at the full profile instead, and the two formats below stay the same.

## Profile file

- Extension `.pinprofile`, type identifier `com.pinboard.profile`, MIME type `application/x-pinboard-profile`.
- Content: one UTF-8 JSON object.
- Readers must **ignore keys they don't recognize**, and treat missing optional keys as absent.
- `formatVersion` (integer, optional) is `1`. Readers should refuse a larger major version they don't know.

### Conventions

| Type | Encoding |
|---|---|
| UUID | Upper-case string, e.g. `"12DA2FDD-B7E7-4952-B6B0-AC6ABF1530CC"` |
| Date | ISO 8601 UTC, e.g. `"2026-10-22T23:19:00Z"`. Readers should also accept a number, meaning seconds since 2001-01-01 UTC (written by early versions). |
| Image (`Data`) | Base64 string of the image file (JPEG or PNG). Pin cutouts are PNG with transparency. |
| Enum | Lower camel-case string, listed below |
| Positions | Normalized `0...1`, measured from the board's top-left |

### Profile

| Key | Type | Notes |
|---|---|---|
| `formatVersion` | Int? | `1` |
| `cardOnly` | Bool? | `true` when this is a name card with no boards or stats |
| `id` | UUID | Stable identity of the person; re-importing the same `id` updates, not duplicates |
| `displayName` | String | |
| `handle` | String | Lowercase `a–z 0–9 . _`, up to 20 characters, no `@`. Not guaranteed unique yet |
| `bio` | String | Up to 160 characters |
| `avatarData` | Image? | Square, up to 512 px |
| `dateJoined` | Date | |
| `stats` | Stats | See below |
| `boards` | [Board] | |

**Stats:** `pinCount`, `boardCount`, `festivalCount`, `artistCount` (Int); `totalValue` (Double, sum of
original purchase prices, in the viewer's currency).

### Board

| Key | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `name` | String | |
| `appearance` | Appearance | |
| `pins` | [Pin] | Oldest first; later pins draw on top |

**Appearance:** `style`, `customBoardData` (Image?), `showShadowbox` (Bool), `lighting`, `lightColor`,
`wall`, `customWallData` (Image?).

| Enum | Values |
|---|---|
| `style` | `cork`, `felt`, `slate`, `linen`, `custom` (uses `customBoardData`) |
| `lighting` | `off`, `ambientGlow`, `ledStrip` |
| `lightColor` | `warmWhite`, `coolWhite`, `red`, `amber`, `green`, `blue`, `purple`, `pink`, `rainbow` |
| `wall` | `plaster`, `brickRed`, `brickWhite`, `concrete`, `roughPlaster`, `planks`, `navy`, `sage`, `blush`, `mustard`, `charcoal`, `custom` (uses `customWallData`) |

Textures for `cork` and the photo walls are bundled with the app (CC0, from ambientCG). A client that
doesn't have one should fall back to a similar solid color.

### Pin

| Key | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `name`, `notes` | String | |
| `imageData` | Image? | |
| `positionX`, `positionY` | Double | Center of the pin, `0...1` of the board's width and height |
| `rotation` | Double | Degrees, clockwise |
| `scale` | Double | Multiple of the base size (90 points on a board about 360 points wide), `0.4...3.0` |
| `artist`, `festival`, `acquiredFrom` | String | May be empty |
| `festivalYear`, `yearAcquired` | Int? | |
| `purchasePrice` | Double? | |
| `yearAcquiredUnknown`, `priceUnknown` | Bool? | `true` means the owner doesn't know, which is different from leaving it blank. Show "Unknown". |
| `isShimmery` | Bool? | A glittery pin: draw a sweeping glint and twinkling sparkles over the pin's photo, only where it's opaque |
| `opensLikeBook` | Bool? | The pin opens like a book |
| `openImageData` | Image? | The pin fully open, both pages side by side (twice as wide as tall), the closed pin matching the right-hand page |
| `isOpen` | Bool? | Whether the owner left it open. A viewer can open and close it for themselves |
| `dateAdded` | Date | |

**Opening a book pin:** the closed photo hinges on its left edge and swings 180° to the left, revealing the right page
(the right half of `openImageData`); its back is the left half of `openImageData`. Fully open, the pin is twice as
wide, centered where the closed pin was. A pin is only openable if `opensLikeBook` is true *and* `openImageData` exists.

**Size and placement:** a pin's size at `scale` 1 is 25% of the board's width, so boards look the same at any size. Keep
the whole pin visible, clear of the board's edge (and of the frame, when `showShadowbox` is on): nudge a pin saved near an
edge inward instead of letting it be cut off.

## Friend link

```
pinboard://friend?v=1&id=<uuid>&name=<text>&handle=<text>&bio=<text>&avatar=<base64url>
```

- `v` and `id` are required and `id` must be a UUID; at least one of `name` and `handle` must be present.
- `bio` and `avatar` are optional. `avatar` is a ~56 px JPEG, **base64url without padding**
  (`-` and `_` instead of `+` and `/`), and is left out if it would exceed 2,500 bytes.
- Text values are percent-encoded per URL rules.
- A link produces a card (`cardOnly: true`). Importing it must never overwrite a friend's full profile
  with the card; only their name, handle, bio, and photo are refreshed.
- When a website exists, the same path and query will be served over `https://`, and apps should accept both.

## Notes for other platforms

- Friends are people the user added deliberately. There is no feed, search, or recommendation of people.
- Show a confirmation (who it is, with Add / Not Now) before adding anyone from a file or link.
- Handles are not unique until there is a server; match friends by `id`, never by handle.
