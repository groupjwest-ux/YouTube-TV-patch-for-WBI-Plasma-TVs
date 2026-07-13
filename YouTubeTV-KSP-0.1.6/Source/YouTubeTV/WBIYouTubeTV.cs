using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Threading;
using UnityEngine;
using UnityEngine.Video;

namespace WildBlueIndustries.YouTubeTV
{
    [KSPModule("YouTube TV")]
    public sealed class WBIYouTubeTV : PartModule
    {
        [KSPField(isPersistant = true)]
        public string mediaUrl = string.Empty;

        [KSPField(isPersistant = true)]
        public bool autoPlay;

        [KSPField(isPersistant = true)]
        public bool loopPlayback;

        [KSPField(isPersistant = true)]
        public bool muted;

        [KSPField(isPersistant = true)]
        public float volume = 0.8f;

        [KSPField]
        public string screenTransform = "Screen";

        [KSPField]
        public int screenWidth = 1280;

        [KSPField]
        public int screenHeight = 720;

        [KSPField]
        public float audioMinDistance = 1.0f;

        [KSPField]
        public float audioMaxDistance = 25.0f;

        [KSPField]
        public int resolverTimeoutSeconds = 45;

        [KSPField]
        public string ytDlpPath = string.Empty;

        [KSPField]
        public string ytDlpFormat = "best[ext=mp4][vcodec^=avc1][acodec!=none][height<=720]/best[ext=mp4][acodec!=none][height<=720]/best[acodec!=none][vcodec!=none][height<=720]";

        [KSPField(guiActive = true, guiActiveEditor = true, guiName = "TV status")]
        public string playbackStatus = "Idle";

        private sealed class ScreenMaterialState
        {
            public Material Material;
            public Texture MainTexture;
            public Texture EmissiveTexture;
            public bool HasMainTexture;
            public bool HasEmissiveTexture;
        }

        private sealed class ResolverCompletion
        {
            public int Generation;
            public YtDlpResolver.ResolveResult Result;
        }

        private readonly List<ScreenMaterialState> _screenMaterials = new List<ScreenMaterialState>();
        private readonly Queue<ResolverCompletion> _resolverCompletions = new Queue<ResolverCompletion>();
        private readonly object _resolverSync = new object();

        private VideoPlayer _videoPlayer;
        private AudioSource _audioSource;
        private RenderTexture _renderTexture;
        private Rect _windowRect = new Rect(240.0f, 120.0f, 560.0f, 365.0f);
        private Vector2 _scrollPosition;
        private string _urlInput = string.Empty;
        private string _resolvedUrl = string.Empty;
        private string _inputLockId;
        private int _windowId;
        private int _resolveGeneration;
        private bool _showWindow;
        private bool _inputLocked;
        private bool _playAfterPrepare;
        private bool _isResolving;
        private bool _screenBoundToVideo;

        [KSPEvent(guiName = "Open YouTube TV", guiActive = true, guiActiveEditor = true, guiActiveUnfocused = true, unfocusedRange = 5.0f)]
        public void ToggleController()
        {
            _showWindow = !_showWindow;
            if (_showWindow)
                _urlInput = mediaUrl ?? string.Empty;
            else
                ReleaseInputLock();
        }

        [KSPEvent(guiName = "Play/Pause TV", guiActive = true, guiActiveEditor = true)]
        public void TogglePlayback()
        {
            if (_videoPlayer != null && _videoPlayer.isPlaying)
            {
                PausePlayback();
                return;
            }

            if (_videoPlayer != null && _videoPlayer.isPrepared)
            {
                ResumePlayback();
                return;
            }

            BeginPlayback(mediaUrl);
        }

        [KSPEvent(guiName = "Stop TV", guiActive = true, guiActiveEditor = true)]
        public void StopTV()
        {
            StopPlayback(false);
        }

        [KSPAction("Play/Pause YouTube TV")]
        public void TogglePlaybackAction(KSPActionParam actionParam)
        {
            TogglePlayback();
        }

        [KSPAction("Stop YouTube TV")]
        public void StopPlaybackAction(KSPActionParam actionParam)
        {
            StopTV();
        }

        public override void OnStart(StartState state)
        {
            base.OnStart(state);

            _windowId = GetInstanceID() ^ 0x59545456;
            _inputLockId = "YouTubeTV-" + GetInstanceID();
            _urlInput = mediaUrl ?? string.Empty;

            CacheScreenMaterials();
            CreatePlaybackObjects();
            UpdateEventLabels();

            if (autoPlay && HighLogic.LoadedSceneIsFlight && !string.IsNullOrEmpty(mediaUrl))
                StartCoroutine(BeginAutoPlay());
        }

        public void Update()
        {
            ProcessResolverCompletions();
            UpdateAudioSettings();
            UpdateEventLabels();
            UpdateInputLock();
        }

        public void OnGUI()
        {
            if (!_showWindow)
                return;

            if (!HighLogic.LoadedSceneIsFlight && !HighLogic.LoadedSceneIsEditor)
                return;

            GUI.skin = HighLogic.Skin;
            _windowRect = GUILayout.Window(_windowId, _windowRect, DrawWindow, "YouTube TV");
        }

        public void OnDestroy()
        {
            _resolveGeneration++;
            ReleaseInputLock();
            DisposePlaybackObjects();
        }

        private IEnumerator BeginAutoPlay()
        {
            yield return new WaitForSeconds(0.75f);
            BeginPlayback(mediaUrl);
        }

        private void DrawWindow(int windowId)
        {
            GUILayout.BeginVertical();

            GUILayout.Label("YouTube URL, direct media URL, or local video path:");
            _urlInput = GUILayout.TextField(_urlInput ?? string.Empty, 2048);

            GUILayout.BeginHorizontal();
            GUI.enabled = !_isResolving;
            if (GUILayout.Button("Load / Play", GUILayout.Height(28.0f)))
                BeginPlayback(_urlInput);
            GUI.enabled = true;

            if (GUILayout.Button(_videoPlayer != null && _videoPlayer.isPlaying ? "Pause" : "Resume", GUILayout.Height(28.0f)))
            {
                if (_videoPlayer != null && _videoPlayer.isPlaying)
                    PausePlayback();
                else
                    ResumePlayback();
            }

            if (GUILayout.Button("Stop", GUILayout.Height(28.0f)))
                StopPlayback(false);

            if (GUILayout.Button("Clear screen", GUILayout.Height(28.0f)))
                StopPlayback(true);
            GUILayout.EndHorizontal();

            GUILayout.Space(5.0f);
            GUILayout.BeginHorizontal();
            loopPlayback = GUILayout.Toggle(loopPlayback, "Loop");
            muted = GUILayout.Toggle(muted, "Mute");
            autoPlay = GUILayout.Toggle(autoPlay, "Autoplay when vessel loads");
            GUILayout.EndHorizontal();

            GUILayout.BeginHorizontal();
            GUILayout.Label("Volume", GUILayout.Width(60.0f));
            volume = GUILayout.HorizontalSlider(volume, 0.0f, 1.0f);
            GUILayout.Label(Mathf.RoundToInt(volume * 100.0f) + "%", GUILayout.Width(45.0f));
            GUILayout.EndHorizontal();

            GUILayout.Space(5.0f);
            _scrollPosition = GUILayout.BeginScrollView(_scrollPosition, GUILayout.Height(115.0f));
            GUILayout.Label("Status: " + playbackStatus);
            if (!string.IsNullOrEmpty(_resolvedUrl))
                GUILayout.Label("Resolved stream: " + Abbreviate(_resolvedUrl, 180));
            GUILayout.Label("YouTube playback uses a user-supplied yt-dlp executable to resolve a temporary, directly playable stream. Direct MP4/WebM and file URLs do not require yt-dlp.");
            GUILayout.EndScrollView();

            GUILayout.BeginHorizontal();
            if (GUILayout.Button("Open source page in browser"))
            {
                string normalized = MediaUrl.NormalizeInput(_urlInput);
                if (!string.IsNullOrEmpty(normalized))
                    Application.OpenURL(normalized);
            }

            if (GUILayout.Button("Close"))
            {
                _showWindow = false;
                ReleaseInputLock();
            }
            GUILayout.EndHorizontal();

            GUI.DragWindow(new Rect(0.0f, 0.0f, 10000.0f, 24.0f));
            GUILayout.EndVertical();
        }

        private void BeginPlayback(string input)
        {
            string normalized = MediaUrl.NormalizeInput(input);
            if (string.IsNullOrEmpty(normalized))
            {
                SetStatus("Enter a valid YouTube URL, media URL, or local file path.");
                return;
            }

            mediaUrl = normalized;
            _urlInput = normalized;
            _resolvedUrl = string.Empty;

            if (MediaUrl.IsYouTubeUrl(normalized))
            {
                BeginYouTubeResolve(normalized);
                return;
            }

            PrepareAndPlay(normalized);
        }

        private void BeginYouTubeResolve(string sourceUrl)
        {
            int generation = ++_resolveGeneration;
            string executable = LocateYtDlpExecutable();
            string format = ytDlpFormat;
            int timeout = Math.Max(5, resolverTimeoutSeconds);

            _isResolving = true;
            _playAfterPrepare = false;
            SetStatus("Resolving YouTube stream...");

            Thread resolverThread = new Thread(delegate()
            {
                YtDlpResolver.ResolveResult result = YtDlpResolver.Resolve(executable, sourceUrl, format, timeout);
                lock (_resolverSync)
                {
                    _resolverCompletions.Enqueue(new ResolverCompletion
                    {
                        Generation = generation,
                        Result = result
                    });
                }
            });

            resolverThread.IsBackground = true;
            resolverThread.Name = "YouTubeTV resolver";
            resolverThread.Start();
        }

        private void ProcessResolverCompletions()
        {
            ResolverCompletion completion = null;
            lock (_resolverSync)
            {
                if (_resolverCompletions.Count > 0)
                    completion = _resolverCompletions.Dequeue();
            }

            if (completion == null || completion.Generation != _resolveGeneration)
                return;

            _isResolving = false;
            if (completion.Result == null || !completion.Result.Success)
            {
                SetStatus(completion.Result == null ? "YouTube resolver failed." : completion.Result.ErrorMessage);
                return;
            }

            _resolvedUrl = completion.Result.StreamUrl;
            PrepareAndPlay(_resolvedUrl);
        }

        private void PrepareAndPlay(string playableUrl)
        {
            if (_videoPlayer == null)
                CreatePlaybackObjects();

            if (_videoPlayer == null)
            {
                SetStatus("Unity VideoPlayer could not be created.");
                return;
            }

            _videoPlayer.Stop();
            _videoPlayer.url = playableUrl;
            _videoPlayer.isLooping = loopPlayback;
            _playAfterPrepare = true;
            BindVideoTexture();
            SetStatus("Preparing video...");

            try
            {
                _videoPlayer.Prepare();
            }
            catch (Exception ex)
            {
                _playAfterPrepare = false;
                SetStatus("Could not prepare video: " + ex.Message);
                Debug.LogError("[YouTubeTV] Video prepare failed: " + ex);
            }
        }

        private void PausePlayback()
        {
            if (_videoPlayer == null || !_videoPlayer.isPlaying)
                return;

            _videoPlayer.Pause();
            SetStatus("Paused");
        }

        private void ResumePlayback()
        {
            if (_videoPlayer == null)
                return;

            if (_videoPlayer.isPrepared)
            {
                BindVideoTexture();
                _videoPlayer.Play();
                SetStatus("Playing");
            }
            else if (!string.IsNullOrEmpty(mediaUrl))
            {
                BeginPlayback(mediaUrl);
            }
        }

        private void StopPlayback(bool restoreScreen)
        {
            _resolveGeneration++;
            _isResolving = false;
            _playAfterPrepare = false;
            _resolvedUrl = string.Empty;

            if (_videoPlayer != null)
                _videoPlayer.Stop();

            if (restoreScreen)
            {
                RestoreScreenTextures();
                SetStatus("Stopped; original screen restored");
            }
            else
            {
                SetStatus("Stopped");
            }
        }

        private void CreatePlaybackObjects()
        {
            if (part == null)
                return;

            if (_renderTexture == null)
            {
                int width = Mathf.Clamp(screenWidth, 256, 3840);
                int height = Mathf.Clamp(screenHeight, 144, 2160);
                _renderTexture = new RenderTexture(width, height, 0, RenderTextureFormat.ARGB32);
                _renderTexture.name = "YouTubeTV-" + part.name + "-" + GetInstanceID();
                _renderTexture.Create();
            }

            if (_audioSource == null)
            {
                _audioSource = part.gameObject.AddComponent<AudioSource>();
                _audioSource.playOnAwake = false;
                _audioSource.spatialBlend = 1.0f;
                _audioSource.rolloffMode = AudioRolloffMode.Linear;
                _audioSource.minDistance = Mathf.Max(0.1f, audioMinDistance);
                _audioSource.maxDistance = Mathf.Max(_audioSource.minDistance, audioMaxDistance);
            }

            if (_videoPlayer == null)
            {
                _videoPlayer = part.gameObject.AddComponent<VideoPlayer>();
                _videoPlayer.playOnAwake = false;
                _videoPlayer.waitForFirstFrame = true;
                _videoPlayer.skipOnDrop = true;
                _videoPlayer.renderMode = VideoRenderMode.RenderTexture;
                _videoPlayer.targetTexture = _renderTexture;
                _videoPlayer.aspectRatio = VideoAspectRatio.FitInside;
                _videoPlayer.audioOutputMode = VideoAudioOutputMode.AudioSource;
                _videoPlayer.controlledAudioTrackCount = 1;
                _videoPlayer.SetTargetAudioSource(0, _audioSource);
                _videoPlayer.prepareCompleted += OnVideoPrepared;
                _videoPlayer.errorReceived += OnVideoError;
                _videoPlayer.loopPointReached += OnVideoEnded;
            }

            UpdateAudioSettings();
        }

        private void DisposePlaybackObjects()
        {
            RestoreScreenTextures();

            if (_videoPlayer != null)
            {
                _videoPlayer.prepareCompleted -= OnVideoPrepared;
                _videoPlayer.errorReceived -= OnVideoError;
                _videoPlayer.loopPointReached -= OnVideoEnded;
                _videoPlayer.Stop();
                Destroy(_videoPlayer);
                _videoPlayer = null;
            }

            if (_audioSource != null)
            {
                Destroy(_audioSource);
                _audioSource = null;
            }

            if (_renderTexture != null)
            {
                _renderTexture.Release();
                Destroy(_renderTexture);
                _renderTexture = null;
            }
        }

        private void OnVideoPrepared(VideoPlayer player)
        {
            if (player == null)
                return;

            player.isLooping = loopPlayback;
            if (player.audioTrackCount > 0)
                player.EnableAudioTrack(0, true);

            UpdateAudioSettings();
            BindVideoTexture();

            if (_playAfterPrepare)
            {
                _playAfterPrepare = false;
                player.Play();
                SetStatus("Playing");
            }
            else
            {
                SetStatus("Ready");
            }
        }

        private void OnVideoError(VideoPlayer player, string message)
        {
            _playAfterPrepare = false;
            SetStatus("Playback error: " + message);
            Debug.LogError("[YouTubeTV] " + message);
        }

        private void OnVideoEnded(VideoPlayer player)
        {
            if (loopPlayback)
                return;

            SetStatus("Finished");
        }

        private void CacheScreenMaterials()
        {
            _screenMaterials.Clear();
            if (part == null)
                return;

            Transform[] targets = part.FindModelTransforms(screenTransform);
            if (targets == null || targets.Length == 0)
            {
                SetStatus("No screen transforms named '" + screenTransform + "' were found.");
                Debug.LogWarning("[YouTubeTV] No screen transforms named " + screenTransform + " on " + part.name);
                return;
            }

            for (int index = 0; index < targets.Length; index++)
            {
                Renderer renderer = targets[index].GetComponent<Renderer>();
                if (renderer == null)
                    continue;

                Material material = renderer.material;
                ScreenMaterialState state = new ScreenMaterialState();
                state.Material = material;
                state.HasMainTexture = material.HasProperty("_MainTex");
                state.HasEmissiveTexture = material.HasProperty("_Emissive");
                if (state.HasMainTexture)
                    state.MainTexture = material.GetTexture("_MainTex");
                if (state.HasEmissiveTexture)
                    state.EmissiveTexture = material.GetTexture("_Emissive");
                _screenMaterials.Add(state);
            }
        }

        private void BindVideoTexture()
        {
            if (_renderTexture == null)
                return;

            if (_screenMaterials.Count == 0)
                CacheScreenMaterials();

            for (int index = 0; index < _screenMaterials.Count; index++)
            {
                ScreenMaterialState state = _screenMaterials[index];
                if (state.Material == null)
                    continue;
                if (state.HasMainTexture)
                    state.Material.SetTexture("_MainTex", _renderTexture);
                if (state.HasEmissiveTexture)
                    state.Material.SetTexture("_Emissive", _renderTexture);
            }

            _screenBoundToVideo = true;
        }

        private void RestoreScreenTextures()
        {
            if (!_screenBoundToVideo)
                return;

            for (int index = 0; index < _screenMaterials.Count; index++)
            {
                ScreenMaterialState state = _screenMaterials[index];
                if (state.Material == null)
                    continue;
                if (state.HasMainTexture)
                    state.Material.SetTexture("_MainTex", state.MainTexture);
                if (state.HasEmissiveTexture)
                    state.Material.SetTexture("_Emissive", state.EmissiveTexture);
            }

            _screenBoundToVideo = false;
        }

        private void UpdateAudioSettings()
        {
            volume = Mathf.Clamp01(volume);
            if (_audioSource != null)
            {
                _audioSource.volume = volume;
                _audioSource.mute = muted;
            }

            if (_videoPlayer != null)
                _videoPlayer.isLooping = loopPlayback;
        }

        private void UpdateEventLabels()
        {
            BaseEvent toggleEvent = Events["TogglePlayback"];
            if (toggleEvent != null)
                toggleEvent.guiName = _videoPlayer != null && _videoPlayer.isPlaying ? "Pause TV" : "Play TV";
        }

        private void SetStatus(string status)
        {
            playbackStatus = string.IsNullOrEmpty(status) ? "Idle" : Abbreviate(status, 300);
        }

        private string LocateYtDlpExecutable()
        {
            string root = KSPUtil.ApplicationRootPath;
            string configured = (ytDlpPath ?? string.Empty).Trim();
            if (!string.IsNullOrEmpty(configured))
            {
                string configuredPath = Path.IsPathRooted(configured) ? configured : Path.Combine(root, configured);
                if (File.Exists(configuredPath))
                    return configuredPath;
                return configured;
            }

            string executableName = Application.platform == RuntimePlatform.WindowsPlayer || Application.platform == RuntimePlatform.WindowsEditor
                ? "yt-dlp.exe"
                : "yt-dlp";
            string bundledPath = Path.Combine(root, "GameData", "YouTubeTV", "PluginData", executableName);
            return File.Exists(bundledPath) ? bundledPath : executableName;
        }

        private void UpdateInputLock()
        {
            if (!_showWindow)
            {
                ReleaseInputLock();
                return;
            }

            Vector2 mousePosition = new Vector2(Input.mousePosition.x, Screen.height - Input.mousePosition.y);
            bool shouldLock = _windowRect.Contains(mousePosition);
            if (shouldLock && !_inputLocked)
            {
                InputLockManager.SetControlLock(ControlTypes.ALL_SHIP_CONTROLS, _inputLockId);
                _inputLocked = true;
            }
            else if (!shouldLock && _inputLocked)
            {
                ReleaseInputLock();
            }
        }

        private void ReleaseInputLock()
        {
            if (!_inputLocked || string.IsNullOrEmpty(_inputLockId))
                return;

            InputLockManager.RemoveControlLock(_inputLockId);
            _inputLocked = false;
        }

        private static string Abbreviate(string value, int maximumLength)
        {
            if (string.IsNullOrEmpty(value) || value.Length <= maximumLength)
                return value;
            return value.Substring(0, maximumLength) + "...";
        }
    }
}
