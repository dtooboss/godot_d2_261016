# Godot VFX Library

[![Godot Engine](https://img.shields.io/badge/Godot-4.5+-blue.svg)](https://godotengine.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-1.0.0-green.svg)](https://github.com/yourusername/godot-vfx-library/releases)

**[中文版](README_CN.md) | English**

![VFX Library Preview](preview_en.png)

A comprehensive collection of **35+ particle effects** and **17+ shaders** for Godot 4, designed specifically for action games like Metroidvania and platformers.

**Production showcase:** [Land of Oblivion](https://store.steampowered.com/app/2457740/Land_of_Oblivion/) — if you like dark-fantasy 2D action-adventure games, wishlisting helps a ton.

[![Wishlist on Steam](https://img.shields.io/badge/Steam-Wishlist%20Now-1b2838?logo=steam&logoColor=white)](https://store.steampowered.com/app/2457740/Land_of_Oblivion/)

## ✨ Features

### 🎆 Particle Effects (35+)
- **Combat Effects**: Blood splash, energy burst, shield break, sparks, combo rings
- **Movement Effects**: Dash trails, jump dust, wall slide sparks  
- **Spell/Skill Effects**: Portal vortex, lightning chain, ice frost, fireball trails
- **Environmental Effects**: Torch fire, fireflies, steam, water splash, falling leaves, rain, snow

### 🎨 Shader Effects (17+)
- **Character Status**: Flash white, blink, dissolve, frozen, poison, burning, petrify
- **Environmental**: Water surface, heat distortion, portal vortex, energy barrier
- **Post-Processing**: Outline glow, radial blur, chromatic aberration, grayscale

### 🎮 Easy-to-Use Managers
- **VFX Manager**: Global combat and UI effects with simple API
- **EnvVFX Manager**: Environmental and atmospheric effects
- **Screen Effects**: Camera shake, freeze frame, damage numbers
- **Auto-cleanup**: Smart memory management for one-shot effects

## 🎮 Production Showcase

[![Land of Oblivion](LandOfOblivion.png)](https://store.steampowered.com/app/2457740/Land_of_Oblivion/)

**[Land of Oblivion](https://store.steampowered.com/app/2457740/Land_of_Oblivion/)** is a 2D action-adventure built with Godot.

This VFX library is used in production for:

- Combat hit feedback and impact VFX
- Spell visuals and status effects
- Screen shake / hit-stop style screen effects
- Environmental ambience

👉 Please consider wishlisting on Steam (it directly helps visibility):

[![Wishlist on Steam](https://img.shields.io/badge/Steam-Wishlist%20Now-1b2838?logo=steam&logoColor=white)](https://store.steampowered.com/app/2457740/Land_of_Oblivion/)
[![Follow on Steam](https://img.shields.io/badge/Steam-Follow-1b2838?logo=steam&logoColor=white)](https://store.steampowered.com/app/2457740/Land_of_Oblivion/)

## 🚀 Quick Start

### Installation

1. **Manual Installation**
   - Download the latest release
   - Extract to your project's `addons/` folder
   - Enable "VFX Library" in Project Settings → Plugins

2. **Git Clone** (Recommended)
   ```bash
   cd your-project/addons/
   git clone https://github.com/haowg/GODOT-VFX-LIBRARY.git vfx_library
   ```
   **Important**: Clone into `addons/vfx_library` (not `GODOT-VFX-LIBRARY`)

3. **Symbolic Link** (Best for Development)
   ```bash
   # Clone once to a central location
   git clone https://github.com/haowg/GODOT-VFX-LIBRARY.git ~/godot-plugins/GODOT-VFX-LIBRARY
   
   # Link to your project
   cd your-project/addons/
   ln -s ~/godot-plugins/GODOT-VFX-LIBRARY/addons/vfx_library vfx_library
   ```
   Great for using the same plugin across multiple projects!

For detailed installation instructions and troubleshooting, see [INSTALLATION.md](INSTALLATION.md).

### Basic Usage

```gdscript
# Screen shake on impact
VFX.screen_shake(10.0, 0.2)

# Blood splash effect
VFX.spawn_blood_splash(enemy.global_position)

# Flash white on damage
VFX.flash_white(player_sprite, 0.1)

# Environmental torch
EnvVFX.create_torch(self, Vector2(100, 50))

# Weather effects
EnvVFX.create_rain(self, 600)
```

## 📖 Documentation

- **[Installation Guide](INSTALLATION.md)** - Detailed setup instructions
- **[API Reference](API_REFERENCE.md)** - Complete function documentation
- **[Demo Examples](addons/vfx_library/demo/)** - Interactive demo scene

## 🎯 Use Cases

**Combat Systems** - Blood splashes, screen shake, damage numbers, critical hit effects  
**Movement Mechanics** - Dash trails, jump dust, wall slide sparks  
**Environmental Design** - Fire sources, weather effects, ambient particles  
**Spell & Magic** - Portal vortex, lightning chains, summoning circles  
**Status Effects** - Visual feedback for freeze, poison, burning states

See the [API Reference](API_REFERENCE.md) for detailed code examples.

## 🎮 Interactive Demo

Experience all effects with the interactive demo scene:

1. Open `addons/vfx_library/demo/vfx_demo.tscn` in Godot
2. Press **Play Scene** (F6)
3. Select effects from the UI list and right-click to spawn them
4. Test all 35+ particle effects and 17+ shaders in real-time

**Features:**
- 📋 Browse effects by category (Combat, Weather, Environmental, etc.)
- 🎨 Test shader effects with animated previews
- 🧪 Performance testing with multiple simultaneous effects
- 🎯 Right-click spawning at cursor position

**[View Demo Guide →](addons/vfx_library/demo/README.md)** for complete effect list and usage instructions.

## 🎨 Customization

All effects are **scene-based** (.tscn files) for easy visual editing:

```
addons/vfx_library/
├── effects/          # Particle effect scenes
├── shaders/          # Shader files
├── demo/             # Demo project
└── docs/             # Documentation
```

- **Particle Effects**: Edit `.tscn` files directly in Godot editor
- **Shaders**: Modify `.gdshader` files or create variants
- **Colors & Timing**: Adjust via GDScript parameters
- **Manager APIs**: Extend `vfx.gd` and `env_vfx.gd` for custom effects

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### How to Contribute
- 🐛 **Report bugs** via GitHub Issues
- 💡 **Suggest features** for new effects or improvements  
- 🎨 **Submit effects** - new particles, shaders, or presets
- 📖 **Improve docs** - examples, tutorials, translations

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built for **Godot 4.5+** 
- Inspired by classic Metroidvania and action games
- Community feedback and contributions
- Special thanks to Godot community for excellent documentation

---

⭐ **Star this repository** if it helps your project!

**Questions?** Open an issue or check the [documentation](API_REFERENCE.md).
