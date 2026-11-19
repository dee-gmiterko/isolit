# IsoLit

**Isometric 2D lighting for Godot 4 - with no light limit.**

Lights and lit surfaces are placed in isometric world space and projected onto the 2D
canvas, so a light at a world position lights floors and walls the way an isometric scene
expects.

---

## Quickstart

1. **Enable the plugin.** Project → Project Settings → Plugins → turn on **IsoLit**.
2. **Set the projection.** Tile size under `isolit/projection` in Project Settings.
3. **Make it dark.** Add an **`IsoCanvasModulate`** and set its color. *(Use this instead
   of Godot's `CanvasModulate`, not alongside it.)*
4. **Let your art catch light.** Add an **`IsoNode`**, give it a world position and a
   surface type, and parent your 2D nodes under it.
5. **Add a light.** Drop an **`IsoPointLight`** in and set its world position.

Everything updates live in the editor.

---

## The nodes

| Node | What it does |
|---|---|
| `IsoNode` | A surface that receives light: floor, wall, or camera-facing. |
| `IsoPointLight` | A light that shines in all directions from a point. |
| `IsoSpotLight` | A cone of light you can aim. |
| `IsoDirectionalLight` | A sun — parallel light across the whole scene. |
| `IsoCanvasModulate` | Sets the scene's darkness/ambient color. |

---

## Shadows

Game code tells each light which tiles around it are blocked through
`update_obstructed`.

---

## License

MIT — see [LICENSE](LICENSE).
