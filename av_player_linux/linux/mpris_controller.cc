#include "mpris_controller.h"

#include <cstring>

// =============================================================================
// MPRIS2 D-Bus interface XML introspection
// =============================================================================

static const gchar kMprisIntrospection[] =
    "<node>"
    "  <interface name='org.mpris.MediaPlayer2'>"
    "    <method name='Raise'/>"
    "    <method name='Quit'/>"
    "    <property name='CanQuit' type='b' access='read'/>"
    "    <property name='CanRaise' type='b' access='read'/>"
    "    <property name='HasTrackList' type='b' access='read'/>"
    "    <property name='Identity' type='s' access='read'/>"
    "    <property name='SupportedUriSchemes' type='as' access='read'/>"
    "    <property name='SupportedMimeTypes' type='as' access='read'/>"
    "  </interface>"
    "  <interface name='org.mpris.MediaPlayer2.Player'>"
    "    <method name='Next'/>"
    "    <method name='Previous'/>"
    "    <method name='Pause'/>"
    "    <method name='PlayPause'/>"
    "    <method name='Stop'/>"
    "    <method name='Play'/>"
    "    <method name='Seek'>"
    "      <arg direction='in' name='Offset' type='x'/>"
    "    </method>"
    "    <method name='SetPosition'>"
    "      <arg direction='in' name='TrackId' type='o'/>"
    "      <arg direction='in' name='Position' type='x'/>"
    "    </method>"
    "    <property name='PlaybackStatus' type='s' access='read'/>"
    "    <property name='Metadata' type='a{sv}' access='read'/>"
    "    <property name='Position' type='x' access='read'/>"
    "    <property name='CanGoNext' type='b' access='read'/>"
    "    <property name='CanGoPrevious' type='b' access='read'/>"
    "    <property name='CanPlay' type='b' access='read'/>"
    "    <property name='CanPause' type='b' access='read'/>"
    "    <property name='CanSeek' type='b' access='read'/>"
    "    <property name='CanControl' type='b' access='read'/>"
    "  </interface>"
    "</node>";

// =============================================================================
// Internal state
// =============================================================================

struct _MprisController {
  guint bus_name_id;
  guint root_reg_id;
  guint player_reg_id;
  GDBusConnection* connection;
  GDBusNodeInfo* introspection_data;

  MprisCommandCallback callback;
  gpointer user_data;

  gchar* playback_status;
  gint64 position_us;

  gchar* meta_title;
  gchar* meta_artist;
  gchar* meta_album;
  gchar* meta_art_url;
};

// =============================================================================
// D-Bus method handlers
// =============================================================================

static void handle_player_method(GDBusConnection* conn,
                                  const gchar* sender,
                                  const gchar* object_path,
                                  const gchar* interface_name,
                                  const gchar* method_name,
                                  GVariant* parameters,
                                  GDBusMethodInvocation* invocation,
                                  gpointer user_data) {
  auto* ctrl = static_cast<MprisController*>(user_data);

  if (strcmp(method_name, "Play") == 0) {
    if (ctrl->callback) ctrl->callback("play", 0, ctrl->user_data);
  } else if (strcmp(method_name, "Pause") == 0) {
    if (ctrl->callback) ctrl->callback("pause", 0, ctrl->user_data);
  } else if (strcmp(method_name, "PlayPause") == 0) {
    const gchar* cmd =
        (ctrl->playback_status && strcmp(ctrl->playback_status, "Playing") == 0)
            ? "pause"
            : "play";
    if (ctrl->callback) ctrl->callback(cmd, 0, ctrl->user_data);
  } else if (strcmp(method_name, "Next") == 0) {
    if (ctrl->callback) ctrl->callback("next", 0, ctrl->user_data);
  } else if (strcmp(method_name, "Previous") == 0) {
    if (ctrl->callback) ctrl->callback("previous", 0, ctrl->user_data);
  } else if (strcmp(method_name, "Stop") == 0) {
    if (ctrl->callback) ctrl->callback("stop", 0, ctrl->user_data);
  } else if (strcmp(method_name, "Seek") == 0) {
    gint64 offset_us = 0;
    g_variant_get(parameters, "(x)", &offset_us);
    // Convert seek offset (microseconds) to absolute position (milliseconds)
    gint64 new_pos_ms = (ctrl->position_us + offset_us) / 1000;
    if (new_pos_ms < 0) new_pos_ms = 0;
    if (ctrl->callback) ctrl->callback("seekTo", new_pos_ms, ctrl->user_data);
  } else if (strcmp(method_name, "SetPosition") == 0) {
    const gchar* track_id = nullptr;
    gint64 pos_us = 0;
    g_variant_get(parameters, "(&ox)", &track_id, &pos_us);
    gint64 pos_ms = pos_us / 1000;
    if (ctrl->callback) ctrl->callback("seekTo", pos_ms, ctrl->user_data);
  }

  g_dbus_method_invocation_return_value(invocation, nullptr);
}

static void handle_root_method(GDBusConnection* conn,
                                const gchar* sender,
                                const gchar* object_path,
                                const gchar* interface_name,
                                const gchar* method_name,
                                GVariant* parameters,
                                GDBusMethodInvocation* invocation,
                                gpointer user_data) {
  // Raise and Quit are no-ops for an embedded plugin
  g_dbus_method_invocation_return_value(invocation, nullptr);
}

// =============================================================================
// D-Bus property handlers
// =============================================================================

static GVariant* build_metadata(MprisController* ctrl) {
  GVariantBuilder builder;
  g_variant_builder_init(&builder, G_VARIANT_TYPE("a{sv}"));

  g_variant_builder_add(&builder, "{sv}", "mpris:trackid",
                        g_variant_new_object_path("/org/mpris/MediaPlayer2/Track/0"));

  if (ctrl->meta_title)
    g_variant_builder_add(&builder, "{sv}", "xesam:title",
                          g_variant_new_string(ctrl->meta_title));
  if (ctrl->meta_artist) {
    GVariantBuilder arr;
    g_variant_builder_init(&arr, G_VARIANT_TYPE("as"));
    g_variant_builder_add(&arr, "s", ctrl->meta_artist);
    g_variant_builder_add(&builder, "{sv}", "xesam:artist",
                          g_variant_builder_end(&arr));
  }
  if (ctrl->meta_album)
    g_variant_builder_add(&builder, "{sv}", "xesam:album",
                          g_variant_new_string(ctrl->meta_album));
  if (ctrl->meta_art_url)
    g_variant_builder_add(&builder, "{sv}", "mpris:artUrl",
                          g_variant_new_string(ctrl->meta_art_url));

  return g_variant_builder_end(&builder);
}

static GVariant* get_player_property(GDBusConnection* conn,
                                      const gchar* sender,
                                      const gchar* object_path,
                                      const gchar* interface_name,
                                      const gchar* property_name,
                                      GError** error,
                                      gpointer user_data) {
  auto* ctrl = static_cast<MprisController*>(user_data);

  if (strcmp(property_name, "PlaybackStatus") == 0)
    return g_variant_new_string(ctrl->playback_status ? ctrl->playback_status : "Stopped");
  if (strcmp(property_name, "Metadata") == 0)
    return build_metadata(ctrl);
  if (strcmp(property_name, "Position") == 0)
    return g_variant_new_int64(ctrl->position_us);
  if (strcmp(property_name, "CanGoNext") == 0)
    return g_variant_new_boolean(TRUE);
  if (strcmp(property_name, "CanGoPrevious") == 0)
    return g_variant_new_boolean(TRUE);
  if (strcmp(property_name, "CanPlay") == 0)
    return g_variant_new_boolean(TRUE);
  if (strcmp(property_name, "CanPause") == 0)
    return g_variant_new_boolean(TRUE);
  if (strcmp(property_name, "CanSeek") == 0)
    return g_variant_new_boolean(TRUE);
  if (strcmp(property_name, "CanControl") == 0)
    return g_variant_new_boolean(TRUE);

  return nullptr;
}

static GVariant* get_root_property(GDBusConnection* conn,
                                    const gchar* sender,
                                    const gchar* object_path,
                                    const gchar* interface_name,
                                    const gchar* property_name,
                                    GError** error,
                                    gpointer user_data) {
  if (strcmp(property_name, "CanQuit") == 0)
    return g_variant_new_boolean(FALSE);
  if (strcmp(property_name, "CanRaise") == 0)
    return g_variant_new_boolean(FALSE);
  if (strcmp(property_name, "HasTrackList") == 0)
    return g_variant_new_boolean(FALSE);
  if (strcmp(property_name, "Identity") == 0)
    return g_variant_new_string("AV Player");
  if (strcmp(property_name, "SupportedUriSchemes") == 0) {
    const gchar* schemes[] = {"file", "http", "https", nullptr};
    return g_variant_new_strv(schemes, -1);
  }
  if (strcmp(property_name, "SupportedMimeTypes") == 0) {
    const gchar* types[] = {"video/mp4", "video/x-matroska", "audio/mpeg", nullptr};
    return g_variant_new_strv(types, -1);
  }
  return nullptr;
}

// =============================================================================
// Properties changed signal helper
// =============================================================================

static void emit_properties_changed(MprisController* ctrl,
                                     const gchar* interface_name,
                                     GVariant* changed_properties) {
  if (ctrl->connection == nullptr) return;

  g_dbus_connection_emit_signal(
      ctrl->connection,
      nullptr,
      "/org/mpris/MediaPlayer2",
      "org.freedesktop.DBus.Properties",
      "PropertiesChanged",
      g_variant_new("(sa{sv}as)", interface_name, changed_properties,
                    nullptr),
      nullptr);
}

// =============================================================================
// Bus acquired callback
// =============================================================================

static const GDBusInterfaceVTable kRootVtable = {
    handle_root_method,
    get_root_property,
    nullptr,
};

static const GDBusInterfaceVTable kPlayerVtable = {
    handle_player_method,
    get_player_property,
    nullptr,
};

static void on_bus_acquired(GDBusConnection* connection,
                             const gchar* name,
                             gpointer user_data) {
  auto* ctrl = static_cast<MprisController*>(user_data);
  ctrl->connection = connection;

  GError* error = nullptr;

  ctrl->root_reg_id = g_dbus_connection_register_object(
      connection,
      "/org/mpris/MediaPlayer2",
      ctrl->introspection_data->interfaces[0],
      &kRootVtable,
      ctrl,
      nullptr,
      &error);
  if (error != nullptr) {
    g_warning("MPRIS root register error: %s", error->message);
    g_clear_error(&error);
  }

  ctrl->player_reg_id = g_dbus_connection_register_object(
      connection,
      "/org/mpris/MediaPlayer2",
      ctrl->introspection_data->interfaces[1],
      &kPlayerVtable,
      ctrl,
      nullptr,
      &error);
  if (error != nullptr) {
    g_warning("MPRIS player register error: %s", error->message);
    g_clear_error(&error);
  }
}

// =============================================================================
// Public API
// =============================================================================

MprisController* mpris_controller_new(MprisCommandCallback callback,
                                       gpointer user_data) {
  auto* ctrl = g_new0(MprisController, 1);
  ctrl->callback = callback;
  ctrl->user_data = user_data;
  ctrl->playback_status = g_strdup("Stopped");
  ctrl->position_us = 0;

  ctrl->introspection_data = g_dbus_node_info_new_for_xml(kMprisIntrospection, nullptr);

  ctrl->bus_name_id = g_bus_own_name(
      G_BUS_TYPE_SESSION,
      "org.mpris.MediaPlayer2.av_pip",
      G_BUS_NAME_OWNER_FLAGS_NONE,
      on_bus_acquired,
      nullptr,
      nullptr,
      ctrl,
      nullptr);

  return ctrl;
}

void mpris_controller_free(MprisController* controller) {
  if (controller == nullptr) return;

  if (controller->connection != nullptr) {
    if (controller->root_reg_id > 0)
      g_dbus_connection_unregister_object(controller->connection, controller->root_reg_id);
    if (controller->player_reg_id > 0)
      g_dbus_connection_unregister_object(controller->connection, controller->player_reg_id);
  }

  if (controller->bus_name_id > 0)
    g_bus_unown_name(controller->bus_name_id);

  if (controller->introspection_data)
    g_dbus_node_info_unref(controller->introspection_data);

  g_free(controller->playback_status);
  g_free(controller->meta_title);
  g_free(controller->meta_artist);
  g_free(controller->meta_album);
  g_free(controller->meta_art_url);
  g_free(controller);
}

void mpris_controller_set_metadata(MprisController* controller,
                                    const gchar* title,
                                    const gchar* artist,
                                    const gchar* album,
                                    const gchar* art_url) {
  if (controller == nullptr) return;

  g_free(controller->meta_title);
  g_free(controller->meta_artist);
  g_free(controller->meta_album);
  g_free(controller->meta_art_url);

  controller->meta_title = g_strdup(title);
  controller->meta_artist = g_strdup(artist);
  controller->meta_album = g_strdup(album);
  controller->meta_art_url = g_strdup(art_url);

  if (controller->connection != nullptr) {
    GVariantBuilder builder;
    g_variant_builder_init(&builder, G_VARIANT_TYPE("a{sv}"));
    g_variant_builder_add(&builder, "{sv}", "Metadata", build_metadata(controller));
    emit_properties_changed(controller, "org.mpris.MediaPlayer2.Player",
                            g_variant_builder_end(&builder));
  }
}

void mpris_controller_set_playback_status(MprisController* controller,
                                           const gchar* status) {
  if (controller == nullptr) return;

  g_free(controller->playback_status);
  controller->playback_status = g_strdup(status);

  if (controller->connection != nullptr) {
    GVariantBuilder builder;
    g_variant_builder_init(&builder, G_VARIANT_TYPE("a{sv}"));
    g_variant_builder_add(&builder, "{sv}", "PlaybackStatus",
                          g_variant_new_string(status));
    emit_properties_changed(controller, "org.mpris.MediaPlayer2.Player",
                            g_variant_builder_end(&builder));
  }
}

void mpris_controller_set_position(MprisController* controller,
                                    gint64 position_us) {
  if (controller == nullptr) return;
  controller->position_us = position_us;
}
