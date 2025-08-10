import app from "ags/gtk4/app";
import { Astal, Gdk, Gtk } from "ags/gtk4";

import WorkspaceButtons from "../workspace-buttons/WorkspaceButtons";

export default function HeaderBar(gdkmonitor: Gdk.Monitor) {
  const { TOP, LEFT, RIGHT } = Astal.WindowAnchor;
  const monitorName: string = gdkmonitor.get_connector();

  return (
    <window
      visible
      name="header-bar"
      class="rounded mx-2 mt-2 py-1"
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      anchor={TOP | LEFT | RIGHT}
      application={app}
    >
      <box halign={Gtk.Align.LEFT} hexpand>
        <WorkspaceButtons monitorName={monitorName} />
      </box>
    </window>
  );
}
