using Godot;

/// <summary>
/// Minimal spike bootstrap. The C# build step compiles this script; the
/// headless Linux smoke test executes it (sets the label text and prints the
/// CI marker). The workflow separately validates that the Android APK is
/// exported and structurally valid, but never launches it on a device or
/// emulator, so actual Android runtime execution remains unverified.
/// </summary>
public partial class SpikeBoot : Node
{
    /// <summary>ASCII-only marker asserted by the CI smoke test.</summary>
    public const string Marker = "LAYER_SORT_SPIKE_OK";

    /// <summary>Human-readable on-screen message.</summary>
    public const string Message = "Layer Sort — Build Spike OK";

    public override void _Ready()
    {
        Label label = GetNode<Label>("Label");
        label.Text = Message;
        GD.Print(Marker);
    }
}
