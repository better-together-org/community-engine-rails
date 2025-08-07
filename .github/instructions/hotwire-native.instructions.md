---
applyTo: "**/*.rb,**/*.js,**/*.html.erb"
---
# Hotwire Native Guidelines

## Core Concepts
- Hotwire Native displays web content in a native shell with platform-specific navigation
- Web content renders in a WebView with native-feeling transitions and behaviors
- Link navigation is intercepted and handled by the native adapter
- Build once for the web, deploy simultaneously to web and native mobile apps
- Progressively enhance with native components where higher fidelity is needed

## Navigation Best Practices
- Design web content to work across web, iOS, and Android
- Links between pages become native screen transitions automatically
- External links open in an in-app browser (SFSafariViewController on iOS, Custom Tabs on Android)
- Use `data-turbo-action="replace"` to replace the current screen instead of pushing a new one
- Ensure all screens are accessible via URLs for proper native navigation

## Path Configuration
- Define platform-specific navigation rules in a JSON configuration file
- Host configuration files at versioned URLs (e.g., `/configurations/ios_v1.json`)
- Include both local (bundled) and remote (server-hosted) configurations
- Use regex patterns to match URLs and apply specific behaviors
- Configuration example:
```json
{
  "settings": {
    "feature_flags": [
      {
        "name": "enable_new_feature",
        "enabled": true
      }
    ]
  },
  "rules": [
    {
      "patterns": [
        "/modal/.*"
      ],
      "properties": {
        "context": "modal"
      }
    },
    {
      "patterns": [
        "/tabs/.*"
      ],
      "properties": {
        "presentation": "refresh"
      }
    }
  ]
}
```

## Bridge Components
- Use Bridge Components for web-to-native communication
- Components have both web (Stimulus) and native (Swift/Kotlin) counterparts
- Register component handlers in your native app and attach web controllers in HTML
- Use for native UI elements like top bar buttons, action sheets, and platform APIs
- Web component implementation example:

```javascript
// app/javascript/controllers/native_button_controller.js
import { Controller } from "@hotwired/stimulus"
import { BridgeComponent } from "@hotwired/bridge"

export default class extends Controller {
  static values = { title: String, style: String }

  connect() {
    this.bridge = new BridgeComponent("button", this)
    this.bridge.send("connect", {
      title: this.titleValue,
      style: this.styleValue || "default"
    })
  }

  disconnect() {
    this.bridge.send("disconnect")
  }

  handleTap(message) {
    // Handle tap event from native
    const form = this.element.closest("form")
    if (form) form.requestSubmit()
  }
}
```

```html
<!-- In your view -->
<div data-controller="native-button"
     data-native-button-title-value="Save"
     data-native-button-style-value="primary">
</div>
```

## Native Screen Integration
- Create fully native screens for high-fidelity interactions
- Register URL routes that map to native screen controllers
- Ensure each native screen has a corresponding URL for consistent navigation
- Share data between web and native using URL parameters or Bridge Components
- Follow platform design guidelines for native screens (Human Interface Guidelines for iOS, Material Design for Android)

## Progressive Enhancement Strategy
- Start with web-only implementation to quickly ship features
- Add Bridge Components for native UI elements and platform integrations
- Build fully native screens only where high fidelity is required
- Maintain a consistent navigation model across all screen types
- Use feature flags in path configuration to enable native features gradually

## Mobile-Optimized HTML/CSS
- Test all web pages in mobile viewports
- Use responsive design principles for fluid layouts
- Ensure tap targets are appropriately sized (minimum 44×44pt on iOS, 48×48dp on Android)
- Optimize images and assets for mobile devices
- Consider mobile-specific meta tags:
```html
<meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="turbo-visit-control" content="reload">
```

## Performance Considerations
- Keep initial page load fast (under 2 seconds)
- Minimize JavaScript usage to conserve battery and performance
- Optimize image sizes for mobile network conditions
- Use Turbo Frames to load content incrementally
- Consider offline capabilities with service workers where appropriate