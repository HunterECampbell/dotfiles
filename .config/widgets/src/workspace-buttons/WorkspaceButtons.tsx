import { Gtk } from "ags/gtk4";
import WorkspaceButton from "./WorkspaceButton";

export default function WorkspaceButtons({
  monitorName,
}: {
  monitorName: string;
}) {
  // NEED TO WATCH HYPRLAND WORKSPACE CHANGES: https://aylur.github.io/astal/guide/libraries/hyprland#library
  const workspaceButtons: number[] = [];

  if (monitorName === "HDMI-A-1") {
    // For monitor HDMI-A-1, display workspaces 11 through 15.
    for (let i = 11; i <= 15; i++) {
      workspaceButtons.push(i);
    }
  } else {
    for (let i = 1; i <= 10; i++) {
      workspaceButtons.push(i);
    }
  }

  return (
    <box
      class="workspace-buttons-wrapper mx-2"
      orientation={Gtk.Orientation.HORIZONATAL}
    >
      {workspaceButtons.map((workspaceNumber) => (
        <WorkspaceButton workspaceNumber={workspaceNumber} />
      ))}
    </box>
  );
}
