import app from "ags/gtk4/app";
import style from "./global-styles/style.scss";
import HeaderBar from "./src/header-bar/HeaderBar";

app.start({
  css: style,
  main() {
    app.get_monitors().map(HeaderBar);
  },
});
