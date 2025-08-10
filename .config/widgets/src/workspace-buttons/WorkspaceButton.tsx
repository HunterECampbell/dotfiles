import { createState } from "ags";
import { exec } from "ags/process";

export default function WorkspaceButton({
  workspaceNumber,
}: {
  workspaceNumber: number;
}) {
  const activeIcon = ""; // U+f111
  const defaultIcon = ""; // U+f192
  const emptyIcon = ""; // U+eabc

  const [icon, setIcon] = createState(emptyIcon);

  const changeWorkspace = () => {
    exec(`hyprctl dispatch workspace ${workspaceNumber}`);
  };

  return (
    <button class="workspace-button rounded" onClicked={changeWorkspace}>
      <label class="workspace-button-icon" label={icon} />
    </button>
  );
}
