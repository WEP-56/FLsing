import {
  ClipboardPaste,
  Copy,
  FileUp,
  Info,
  Link2,
  Loader2,
  MoreVertical,
  Pencil,
  Plus,
  Power,
  RefreshCw,
  Trash2,
} from "lucide-react";
import { motion } from "framer-motion";
import { useRef, useState } from "react";
import { ACCENT, Dialog, EASE, Field, PopMenu, Sheet, useLongPress, type Sub } from "../lib/ui";

interface Props {
  open: boolean;
  onClose: () => void;
  subs: Sub[];
  onEnable: (id: string) => void;
  onAdd: (name: string, url: string) => void;
  onEdit: (id: string, name: string, url: string) => void;
  onUpdate: (id: string) => void;
  onDelete: (id: string) => void;
  updatingIds: string[];
  toast: (msg: string) => void;
}

type EditorState = { mode: "add" | "edit"; id?: string; name: string; url: string } | null;

export default function SubscriptionDrawer(p: Props) {
  const [addMenu, setAddMenu] = useState(false);
  const [menuFor, setMenuFor] = useState<string | null>(null);
  const [editor, setEditor] = useState<EditorState>(null);
  const [del, setDel] = useState<Sub | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  const importClipboard = async () => {
    try {
      const text = (await navigator.clipboard.readText()).trim();
      if (text) {
        setEditor({ mode: "add", name: "", url: text.slice(0, 300) });
        p.toast("已读取剪贴板");
      } else {
        p.toast("剪贴板为空");
      }
    } catch {
      setEditor({ mode: "add", name: "", url: "" });
      p.toast("无法读取剪贴板，请手动粘贴");
    }
  };

  return (
    <Sheet open={p.open} onClose={p.onClose}>
      {/* header */}
      <div className="flex items-center justify-between px-5 pb-4 pt-2">
        <h2 className="t1 text-[22px] font-bold tracking-tight">订阅管理</h2>
        <div className="relative">
          <button
            onClick={() => setAddMenu(true)}
            aria-label="添加订阅"
            className="sf2 hov t1 grid h-10 w-10 place-items-center rounded-full transition-all active:scale-95"
          >
            <Plus size={19} strokeWidth={2} />
          </button>
          <PopMenu
            open={addMenu}
            onClose={() => setAddMenu(false)}
            items={[
              { icon: Link2, label: "链接导入", onClick: () => setEditor({ mode: "add", name: "", url: "" }) },
              { icon: ClipboardPaste, label: "剪贴板", onClick: importClipboard },
              { icon: FileUp, label: "文件导入", onClick: () => fileRef.current?.click() },
            ]}
          />
        </div>
      </div>

      {/* list */}
      <div className="no-scrollbar flex-1 space-y-2.5 overflow-y-auto px-5 pb-3">
        {p.subs.map((s, i) => (
          <SubCard
            key={s.id}
            sub={s}
            index={i}
            updating={p.updatingIds.includes(s.id)}
            menuOpen={menuFor === s.id}
            onMenu={() => setMenuFor(s.id)}
            onMenuClose={() => setMenuFor(null)}
            onEnable={() => p.onEnable(s.id)}
            onEdit={() => setEditor({ mode: "edit", id: s.id, name: s.name, url: s.url })}
            onUpdate={() => p.onUpdate(s.id)}
            onDelete={() => setDel(s)}
            toast={p.toast}
          />
        ))}
        {p.subs.length === 0 && (
          <div className="t5 grid place-items-center py-20 text-[13px]">暂无订阅，点击右上角添加</div>
        )}
      </div>

      {/* footer */}
      <div className="t5 flex items-center gap-1.5 px-5 pb-7 pt-2 text-[11.5px]">
        <Info size={12} />
        长按订阅项可快速操作
      </div>

      <input
        ref={fileRef}
        type="file"
        accept=".yaml,.yml,.txt,.conf"
        className="hidden"
        onChange={(e) => {
          const f = e.target.files?.[0];
          if (f) p.onAdd(f.name.replace(/\.[^.]+$/, ""), `local://files/${f.name}`);
          e.target.value = "";
        }}
      />

      {/* add / edit dialog */}
      <Dialog
        open={!!editor}
        onClose={() => setEditor(null)}
        title={editor?.mode === "edit" ? "编辑订阅" : "添加订阅"}
        actions={[
          { label: "取消", onClick: () => setEditor(null) },
          {
            label: editor?.mode === "edit" ? "保存" : "添加",
            primary: true,
            onClick: () => {
              if (!editor) return;
              const url = editor.url.trim();
              if (!url) return;
              const name = editor.name.trim() || "未命名订阅";
              if (editor.mode === "edit" && editor.id) p.onEdit(editor.id, name, url);
              else p.onAdd(name, url);
              setEditor(null);
            },
          },
        ]}
      >
        <div className="mt-3 space-y-3">
          <Field
            label="名称（可选）"
            placeholder="例如：Main"
            value={editor?.name ?? ""}
            onChange={(e) => setEditor((s) => (s ? { ...s, name: e.target.value } : s))}
          />
          <Field
            label="订阅链接"
            placeholder="https://"
            value={editor?.url ?? ""}
            onChange={(e) => setEditor((s) => (s ? { ...s, url: e.target.value } : s))}
          />
        </div>
      </Dialog>

      {/* delete confirm */}
      <Dialog
        open={!!del}
        onClose={() => setDel(null)}
        title="删除订阅"
        actions={[
          { label: "取消", onClick: () => setDel(null) },
          {
            label: "删除",
            danger: true,
            onClick: () => {
              if (del) p.onDelete(del.id);
              setDel(null);
            },
          },
        ]}
      >
        <p className="t3 mt-2 text-[13px] leading-relaxed">
          确定删除「{del?.name}」吗？该订阅及其全部节点将被移除，此操作无法撤销。
        </p>
      </Dialog>
    </Sheet>
  );
}

/* --------------------------------- sub card --------------------------------- */

function SubCard({
  sub: s,
  index: i,
  updating,
  menuOpen,
  onMenu,
  onMenuClose,
  onEnable,
  onEdit,
  onUpdate,
  onDelete,
  toast,
}: {
  sub: Sub;
  index: number;
  updating: boolean;
  menuOpen: boolean;
  onMenu: () => void;
  onMenuClose: () => void;
  onEnable: () => void;
  onEdit: () => void;
  onUpdate: () => void;
  onDelete: () => void;
  toast: (m: string) => void;
}) {
  const lp = useLongPress(onMenu);
  return (
    <motion.div
      initial={{ opacity: 0, y: 14 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 0.04 + i * 0.04, duration: 0.32, ease: EASE }}
      {...lp}
      onClick={(e) => {
        lp.onClickCapture(e);
        if (!e.defaultPrevented) onEnable();
      }}
      className="sf1 act relative cursor-pointer rounded-2xl border bd1 p-4 transition-colors"
    >
      <div className="flex items-center justify-between gap-3">
        <span className="t1 truncate text-[15px] font-medium">{s.name}</span>
        <div className="flex items-center gap-1">
          <span
            className={`rounded-full px-2.5 py-[5px] text-[10.5px] font-medium ${s.active ? "" : "sf2 t4"}`}
            style={s.active ? { background: "var(--accent-soft)", color: ACCENT } : undefined}
          >
            {s.active ? "已启用" : "未启用"}
          </span>
          <div className="relative">
            <button
              onClick={(e) => {
                e.stopPropagation();
                onMenu();
              }}
              aria-label="更多操作"
              className="t4 grid h-8 w-7 place-items-center"
            >
              <MoreVertical size={16} />
            </button>
            <PopMenu
              open={menuOpen}
              onClose={onMenuClose}
              items={[
                { icon: Power, label: s.active ? "停用" : "设为启用", onClick: onEnable },
                { icon: RefreshCw, label: "更新", onClick: onUpdate },
                { icon: Pencil, label: "编辑", onClick: onEdit },
                {
                  icon: Copy,
                  label: "复制链接",
                  onClick: () => {
                    navigator.clipboard?.writeText(s.url).catch(() => undefined);
                    toast("已复制链接");
                  },
                },
                { icon: Trash2, label: "删除", danger: true, onClick: onDelete },
              ]}
            />
          </div>
        </div>
      </div>
      <div className="t5 mt-1 truncate text-[11.5px]">{s.url}</div>
      <div className="t5 mt-1.5 flex items-center gap-1.5 text-[11px]">
        {updating ? (
          <>
            <Loader2 size={11} className="animate-spin" />
            正在更新…
          </>
        ) : (
          <>更新时间：{s.updated}</>
        )}
      </div>
    </motion.div>
  );
}
