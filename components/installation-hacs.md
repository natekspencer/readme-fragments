## ⬇️ Installation

### HACS (Recommended)

[![Open your Home Assistant instance and open a repository inside the Home Assistant Community Store.](https://my.home-assistant.io/badges/hacs_repository.svg)](https://my.home-assistant.io/redirect/hacs_repository/?owner={{OWNER}}&repository={{REPO}}&category=integration)

To download:

{{INCLUDE:components/installation-hacs-{{HACS_TYPE}}}}

### Manual

If you prefer manual installation:

1. Download or clone this repository
2. Copy the `custom_components/{{DOMAIN}}` folder to your Home Assistant `custom_components` directory. If this is your first custom component, you man need to create the directory.  
   Example paths:
   - Hassio: `/config/custom_components`
   - Hassbian: `/home/homeassistant/.homeassistant/custom_components`
3. Restart Home Assistant

> ⚠️ Manual installation will not provide automatic update notifications. HACS installation is recommended unless you have a specific need.

## ➕ Setup

Once installed, you can setup the integration by clicking on the following badge:

[![Open your Home Assistant instance and start setting up a new integration.](https://my.home-assistant.io/badges/config_flow_start.svg)](https://my.home-assistant.io/redirect/config_flow_start/?domain={{DOMAIN}})

Alternatively:

1. Go to [Settings > Devices & services](https://my.home-assistant.io/redirect/integrations/)
2. In the bottom-right corner, select **Add integration**
3. Type `{{DOMAIN}}` and select the **{{DOMAIN}}** integration
4. Follow the instructions to add the integration to your Home Assistant
