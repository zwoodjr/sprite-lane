#!/usr/bin/env python3
"""Generate the feature build profile for Wanderer's slim web template.

  python3 tools/web/gen_build_profile.py extension_api.json > tools/web/wanderer.build

extension_api.json comes from the matching engine:
  Godot_v4.3-stable --headless --dump-extension-api

Like the editor's "Detect from project", but conservative: a class is disabled
only when
  * it belongs to one of the FAMILIES below (whole feature areas the game does
    not use: networking, XR, navigation, video, graph/code editors, skeletons,
    joints, particles on the GPU, ...),
  * its name never appears in any project script, scene, resource or .import,
  * no class the project does use inherits from it, and
  * it is not in KEEP (things the engine creates internally).
Everything 2D, audio/OGG, WebP, fonts/text, GDScript, input and UI the game
touches stays registered. disabled_build_options carries the module switches
(3D, text server, codecs and modules the game does not ship).
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

FAMILIES = [
    r"^(ENet|WebRTC|WebSocket|UPNP|Multiplayer|SceneMultiplayer|OfflineMultiplayer|PacketPeer|StreamPeerTCP|StreamPeerTLS|TCPServer|UDPServer|DTLSServer|TLSOptions|HTTPRequest|HTTPClient|JSONRPC)",
    r"^(XR|OpenXR|WebXR|MobileVR)",
    r"^Navigation",
    r"^(Video|Theora)",
    r"^(Graph(Edit|Node|Frame|Element)|CodeEdit|CodeHighlighter|SyntaxHighlighter|ColorPicker|ColorPickerButton|FileDialog|Tree|TreeItem|SplitContainer|HSplitContainer|VSplitContainer|SubViewportContainer)$",
    r"^(Skeleton2D|Bone2D|SkeletonModification|SkeletonModificationStack|PhysicalBone2D|Polygon2D_unused)",
    r"^(Joint2D|PinJoint2D|GrooveJoint2D|DampedSpringJoint2D)$",
    r"^(GPUParticles2D|ParticleProcessMaterial|ParticleProcessMaterial)$",
    r"^(AnimationTree|AnimationNode|AnimationRootNode)",
    r"^(Parallax2D|ParallaxBackground|ParallaxLayer|RemoteTransform2D|TouchScreenButton|LightOccluder2D|OccluderPolygon2D|MeshInstance2D|MultiMeshInstance2D|PointLight2D|DirectionalLight2D)$",
    r"^(Crypto|CryptoKey|X509Certificate|HMACContext|AESContext|HashingContext_unused)$",
    r"^(RegEx|RegExMatch|ZIPReader|ZIPPacker|FastNoiseLite|Noise|NoiseTexture2D|NoiseTexture3D)$",
    r"^(AudioStreamMicrophone|AudioEffectCapture|AudioEffectRecord|AudioEffectSpectrumAnalyzer|AudioStreamInteractive|AudioStreamSynchronized|AudioStreamPlaylist|AudioStreamMP3|AudioStreamGenerator)",
    r"^(CameraFeed|CameraServer|CameraTexture)$",
    r"^(GLTF|FBX|CSG|GridMap|MeshLibrary)",
    r"^(Expression|ScriptCreateDialog|ConfirmationDialog_unused)$",
]
KEEP = {
    # Created by the engine itself, not by the project.
    "Window", "AcceptDialog", "ConfirmationDialog", "PopupMenu", "Popup", "PopupPanel",
    "HashingContext", "SubViewport", "Timer", "ScrollBar", "HScrollBar", "VScrollBar",
    "LineEdit", "Label", "TextEdit", "RichTextLabel", "SpinBox", "OptionButton",
    "AudioStreamWAV", "AudioStreamOggVorbis", "AudioStreamPlaybackOggVorbis",
    "AudioStreamRandomizer", "CPUParticles2D", "JavaScriptBridge", "JavaScriptObject",
    # Servers / singletons and base classes the SceneTree, debugger and
    # GDScript's global scope touch at startup even when the game never does.
    "MultiplayerAPI", "MultiplayerAPIExtension", "MultiplayerPeer", "MultiplayerPeerExtension",
    "OfflineMultiplayerPeer", "PacketPeer", "PacketPeerExtension", "PacketPeerStream",
    "PacketPeerUDP", "StreamPeerTCP", "TCPServer", "StreamPeerTLS", "TLSOptions",
    "Crypto", "CryptoKey", "X509Certificate", "HMACContext", "AESContext",
    "NavigationServer2D", "NavigationServer3D", "XRServer", "XRInterface", "XRTracker",
    "XRPositionalTracker", "XRPose", "CameraServer", "CameraFeed", "HTTPClient",
}
SCAN_EXT = (".gd", ".tscn", ".tres", ".import", ".godot", ".cfg", ".json", ".gdshader")

DISABLED_BUILD_OPTIONS = {
    "disable_3d": True,
    "module_text_server_adv_enabled": False,
    "module_text_server_fb_enabled": True,
    "module_astcenc_enabled": False,
    "module_basis_universal_enabled": False,
    "module_bmp_enabled": False,
    "module_camera_enabled": False,
    "module_csg_enabled": False,
    "module_cvtt_enabled": False,
    "module_dds_enabled": False,
    "module_enet_enabled": False,
    "module_etcpak_enabled": False,
    "module_fbx_enabled": False,
    "module_gltf_enabled": False,
    "module_gridmap_enabled": False,
    "module_hdr_enabled": False,
    "module_interactive_music_enabled": False,
    "module_jpg_enabled": False,
    "module_jsonrpc_enabled": False,
    "module_ktx_enabled": False,
    "module_lightmapper_rd_enabled": False,
    "module_mbedtls_enabled": False,
    "module_meshoptimizer_enabled": False,
    "module_minimp3_enabled": False,
    "module_mobile_vr_enabled": False,
    "module_msdfgen_enabled": False,
    "module_multiplayer_enabled": False,
    "module_navigation_enabled": False,
    "module_noise_enabled": False,
    "module_openxr_enabled": False,
    "module_raycast_enabled": False,
    "module_regex_enabled": False,
    "module_squish_enabled": False,
    "module_tga_enabled": False,
    "module_theora_enabled": False,
    "module_tinyexr_enabled": False,
    "module_upnp_enabled": False,
    "module_vhacd_enabled": False,
    "module_webrtc_enabled": False,
    "module_websocket_enabled": False,
    "module_webxr_enabled": False,
    "module_xatlas_unwrap_enabled": False,
    "module_zip_enabled": False,
}


def project_text():
    out = []
    for dp, dns, fns in os.walk(ROOT):
        rel = os.path.relpath(dp, ROOT)
        if rel != "." and (rel.startswith((".godot", "tools/art_src")) or os.path.basename(rel).startswith(".")):
            dns[:] = []
            continue
        for f in fns:
            if f.endswith(SCAN_EXT):
                out.append(open(os.path.join(dp, f), errors="ignore").read())
    return "\n".join(out)


def main():
    api = json.load(open(sys.argv[1]))
    parent = {c["name"]: c.get("inherits") for c in api["classes"]}
    text = project_text()
    words = set(re.findall(r"[A-Za-z_][A-Za-z0-9_]*", text))
    used = {c for c in parent if c in words}
    needed = set()
    for c in used | KEEP:
        while c:
            needed.add(c)
            c = parent.get(c)
    fam = [re.compile(f) for f in FAMILIES]
    disabled = sorted(c for c in parent
                      if c not in needed and any(f.search(c) for f in fam))
    # A class can only go if every descendant goes too.
    dis = set(disabled)
    changed = True
    while changed:
        changed = False
        for c, p in parent.items():
            if c not in dis and p in dis:
                dis.discard(p)
                changed = True
    prof = {"type": "build_profile", "disabled_classes": sorted(dis),
            "disabled_build_options": DISABLED_BUILD_OPTIONS}
    json.dump(prof, sys.stdout, indent="\t")
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
