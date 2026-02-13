# av_player_platform_interface

A common platform interface for the `av_player` plugin.

This interface allows platform-specific implementations of the `av_player` plugin, as well as the plugin itself, to ensure they are supporting the same interface.

## Usage

To implement a new platform-specific implementation of `av_player`, extend `AvPlayerPlatform` with an implementation that performs the platform-specific behavior.
