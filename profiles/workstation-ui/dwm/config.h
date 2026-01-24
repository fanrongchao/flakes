/* See LICENSE file for copyright and license details. */

/* Media keys (XF86Audio*) */
#include <X11/XF86keysym.h>

/* appearance */
static const unsigned int borderpx  = 2;        /* border pixel of windows */
static const unsigned int snap      = 32;       /* snap pixel */
static const int showbar            = 1;        /* 0 means no bar */
static const int topbar             = 1;        /* 0 means bottom bar */

/* gaps (match Hyprland-ish spacing) */
static const int smartgaps          = 1;        /* 1 means no outer gap when only one window */
static const unsigned int gappih    = 6;        /* inner horizontal gap */
static const unsigned int gappiv    = 6;        /* inner vertical gap */
static const unsigned int gappoh    = 10;       /* outer horizontal gap */
static const unsigned int gappov    = 10;       /* outer vertical gap */
static const char *fonts[]          = {
  "JetBrainsMono Nerd Font:size=11",
  "Noto Sans CJK SC:size=11",
};
static const char dmenufont[]       = "JetBrainsMono Nerd Font:size=11";

static const char col_bg[]          = "#0f1115";
static const char col_bg_alt[]      = "#171a21";
static const char col_fg[]          = "#d7dce2";
static const char col_accent[]      = "#5fb3b3";

static const char *colors[][3]      = {
  /*               fg         bg           border   */
  [SchemeNorm] = { col_fg,    col_bg,      col_bg_alt },
  [SchemeSel]  = { col_bg,    col_accent,  col_accent },
};

/* tagging */
static const char *tags[] = { "1", "2", "3", "4", "5", "6", "7", "8", "9" };

static const Rule rules[] = {
  /* class      instance    title       tags mask     isfloating   monitor */
  { "Gimp",     NULL,       NULL,       0,            1,           -1 },
  { "Firefox",  NULL,       NULL,       1 << 1,       0,           -1 },
};

/* layout(s) */
static const float mfact     = 0.50; /* factor of master area size [0.05..0.95] */
static const int nmaster     = 1;    /* number of clients in master area */
static const int resizehints = 1;    /* 1 means respect size hints in tiled resizals */
static const int lockfullscreen = 1; /* 1 will force focus on the fullscreen window */

static const Layout layouts[] = {
  /* symbol     arrange function */
  { "HHH",       nrowgrid }, /* Hypr-like grid; first entry is default */
  { "[]=",       tile },
  { "><>",       NULL },
  { "[M]",       monocle },
};

/* key definitions */
#define MODKEY Mod1Mask
#define TAGKEYS(KEY,TAG) \
  { MODKEY,                       KEY,      view,           {.ui = 1 << TAG} }, \
  { MODKEY|ControlMask,           KEY,      toggleview,     {.ui = 1 << TAG} }, \
  { MODKEY|ShiftMask,             KEY,      tagandview,     {.ui = 1 << TAG} }, \
  { MODKEY|ControlMask|ShiftMask, KEY,      toggletag,      {.ui = 1 << TAG} },

/* helper for spawning shell commands in the pre dwm-5.0 fashion */
#define SHCMD(cmd) { .v = (const char*[]){ "/bin/sh", "-c", cmd, NULL } }

static const char *termcmd[]  = { "kitty", NULL };
static const char *roficmd[]  = { "rofi", "-show", "drun", NULL };
static const char *chromecmd[] = { "google-chrome-stable", NULL };
static const char *screencmd[] = { "flameshot", "gui", NULL };
static const char *clipboardcmd[] = { "copyq", "toggle", NULL };
static const char *screenwin[] = { "flameshot-active-window", NULL };

/* dwm expects these symbols to exist (even if you prefer rofi). */
static char dmenumon[2] = "0";
static const char *dmenucmd[] = { "dmenu_run", "-m", dmenumon, "-fn", dmenufont,
  "-nb", col_bg, "-nf", col_fg, "-sb", col_accent, "-sf", col_bg, NULL };

/* focusdir directions (must match the patch): 0 left, 1 right, 2 up, 3 down */
static Key keys[] = {
  /* modifier                     key        function        argument */
  /* Ensure Ctrl+Space always toggles IM (works even in apps not integrated). */
  { ControlMask,                  XK_space,  spawn,          SHCMD("fcitx5-remote -t >/dev/null 2>&1") },

  /* ROG media keys (F10/F11 usually map to these). */
  { 0,                            XF86XK_AudioLowerVolume, spawn, SHCMD("pamixer -d 5 >/dev/null 2>&1") },
  { 0,                            XF86XK_AudioRaiseVolume, spawn, SHCMD("pamixer -i 5 >/dev/null 2>&1") },
  { 0,                            XF86XK_AudioMute,        spawn, SHCMD("pamixer -t >/dev/null 2>&1") },

  { MODKEY,                       XK_Return, spawn,          {.v = termcmd } },
  { MODKEY,                       XK_d,      spawn,          {.v = roficmd } },
  { MODKEY,                       XK_w,      spawn,          {.v = chromecmd } },
  { MODKEY,                       XK_s,      spawn,          {.v = screencmd } },
  { MODKEY,                       XK_c,      spawn,          {.v = clipboardcmd } },
  { MODKEY|ShiftMask,             XK_s,      spawn,          {.v = screenwin } },

  { MODKEY,                       XK_h,      focusdir,       {.i = 0 } },
  { MODKEY,                       XK_l,      focusdir,       {.i = 1 } },
  { MODKEY,                       XK_k,      focusdir,       {.i = 2 } },
  { MODKEY,                       XK_j,      focusdir,       {.i = 3 } },

  /* In monocle (and other overlapping cases), directional focus is ambiguous.
   * Use focusstack to cycle windows.
   */
  { MODKEY,                       XK_Tab,    focusstack,     {.i = +1 } },
  { MODKEY|ShiftMask,             XK_Tab,    focusstack,     {.i = -1 } },

  /* Quick window switcher */
  { MODKEY|ShiftMask,             XK_d,      spawn,          SHCMD("rofi -show window") },

  /* Hypr-like directional swap */
  { MODKEY|ShiftMask,             XK_h,      swapdir,        {.i = 0 } },
  { MODKEY|ShiftMask,             XK_l,      swapdir,        {.i = 1 } },
  { MODKEY|ShiftMask,             XK_k,      swapdir,        {.i = 2 } },
  { MODKEY|ShiftMask,             XK_j,      swapdir,        {.i = 3 } },

  /* Master width */
  { MODKEY|ControlMask,           XK_h,      setmfact,       {.f = -0.05 } },
  { MODKEY|ControlMask,           XK_l,      setmfact,       {.f = +0.05 } },

  /* Promote to master */
  { MODKEY|ShiftMask,             XK_Return, zoom,           {0} },

  { MODKEY,                       XK_f,      togglefullscreen, {0} },

  { MODKEY,                       XK_b,      togglebar,      {0} },
  { MODKEY,                       XK_g,      setlayout,      {.v = &layouts[0]} },
  /* Tile layout, promote focused to master (on the right). */
  { MODKEY,                       XK_t,      setlayoutzoom,  {.v = &layouts[1]} },
  { MODKEY,                       XK_y,      setlayout,      {.v = &layouts[2]} },
  { MODKEY,                       XK_m,      setlayout,      {.v = &layouts[3]} },
  /* Cycle layouts (grid -> tile -> floating -> monocle). */
  { MODKEY,                       XK_space,  cyclelayout,    {.i = +1 } },
  { MODKEY|ControlMask,           XK_space,  cyclelayout,    {.i = -1 } },
  { MODKEY|ShiftMask,             XK_space,  togglefloating, {0} },

  { MODKEY,                       XK_0,      view,           {.ui = ~0 } },
  { MODKEY|ShiftMask,             XK_0,      tag,            {.ui = ~0 } },
  { MODKEY,                       XK_comma,  focusmon,       {.i = -1 } },
  { MODKEY,                       XK_period, focusmon,       {.i = +1 } },
  { MODKEY|ShiftMask,             XK_comma,  tagmon,         {.i = -1 } },
  { MODKEY|ShiftMask,             XK_period, tagmon,         {.i = +1 } },

  TAGKEYS(                        XK_1,                      0)
  TAGKEYS(                        XK_2,                      1)
  TAGKEYS(                        XK_3,                      2)
  TAGKEYS(                        XK_4,                      3)
  TAGKEYS(                        XK_5,                      4)
  TAGKEYS(                        XK_6,                      5)
  TAGKEYS(                        XK_7,                      6)
  TAGKEYS(                        XK_8,                      7)
  TAGKEYS(                        XK_9,                      8)

  { MODKEY|ShiftMask,             XK_q,      quit,           {0} },
  { MODKEY,                       XK_q,      killclient,     {0} },
};

/* button definitions */
static const Button buttons[] = {
  /* click                event mask      button          function        argument */
  { ClkLtSymbol,          0,              Button1,        setlayout,      {0} },
  { ClkLtSymbol,          0,              Button3,        setlayout,      {.v = &layouts[2]} },
  { ClkWinTitle,          0,              Button2,        zoom,           {0} },
  { ClkStatusText,        0,              Button2,        spawn,          {.v = termcmd } },
  { ClkClientWin,         MODKEY,         Button1,        movemouse,      {0} },
  { ClkClientWin,         MODKEY,         Button3,        resizemouse,    {0} },
  { ClkTagBar,            0,              Button1,        view,           {0} },
  { ClkTagBar,            0,              Button3,        toggleview,     {0} },
  { ClkTagBar,            MODKEY,         Button1,        tag,            {0} },
  { ClkTagBar,            MODKEY,         Button3,        toggletag,      {0} },
};
