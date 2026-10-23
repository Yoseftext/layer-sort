using Godot;

/// <summary>
/// Minimal spike bootstrap. The C# build step compiles this script; the
/// headless Linux smoke test executes it (sets the label text and prints the
/// CI marker). On Android the scene starts with a neutral waiting message and
/// only C# code replaces it, so the visible label proves managed execution.
/// </summary>
public partial class SpikeBoot : Node
{
    /// <summary>ASCII-only marker asserted by the CI smoke test.</summary>
    public const string Marker = "LAYER_SORT_SPIKE_OK";

    /// <summary>Human-readable on-screen message set only by C#.</summary>
    public const string Message = "Layer Sort — C# Runtime OK";

    private Label _label = null!;
    private double _runtimeSeconds;
    private int _lastReportedSecond = -1;

    public override void _Ready()
    {
        _label = GetNode<Label>("Label");
        _label.Text = Message;
        GD.Print(Marker);
    }

    public override void _Process(double delta)
    {
        _runtimeSeconds += delta;
        int wholeSeconds = (int)_runtimeSeconds;
        if (wholeSeconds == _lastReportedSecond)
            return;

        _lastReportedSecond = wholeSeconds;
        _label.Text = $"{Message} — {wholeSeconds}s";
        GD.Print($"LAYER_SORT_ANDROID_TICK {wholeSeconds}");
    }
}
