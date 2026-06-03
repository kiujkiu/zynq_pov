"""Use OBS WebSocket to take a screenshot of current scene."""
try:
    from obswebsocket import obsws, requests as obsreq
except ImportError:
    print("ERROR: obs-websocket-py not installed. pip install obs-websocket-py")
    raise SystemExit(1)

# Default OBS WebSocket: 127.0.0.1:4455, password optional
client = obsws("127.0.0.1", 4455, "")
try:
    client.connect()
    # Get current scene
    cs = client.call(obsreq.GetCurrentProgramScene())
    print(f"Current scene: {cs.datain.get('currentProgramSceneName', '?')}")
    # Get source list
    sl = client.call(obsreq.GetSceneItemList(sceneName=cs.datain.get('currentProgramSceneName')))
    for it in sl.datain.get('sceneItems', []):
        print(f"  source: {it.get('sourceName')} type={it.get('inputKind', '?')}")
    # Screenshot
    r = client.call(obsreq.SaveSourceScreenshot(
        sourceName=cs.datain.get('currentProgramSceneName'),
        imageFormat="png",
        imageFilePath=r"D:\claude_workspace\pov3d\zynq_pov\obs_screen.png",
    ))
    print("screenshot saved")
except Exception as e:
    print(f"ERR: {e}")
finally:
    client.disconnect()
