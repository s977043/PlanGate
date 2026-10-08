"""Optional, non-authoritative review feedback widget for PlanGate HTML (stdlib only)."""
import hashlib
import html
import json
import os
import re

MAX_BYTES = 131072
ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$")

def _read(path, limit=None):
    if os.path.islink(path) or not os.path.isfile(path):
        raise ValueError("not a regular file: " + str(path))
    if limit is not None and os.path.getsize(path) > limit:
        raise ValueError("question file too large")
    with open(path, "rb") as stream:
        data = stream.read(limit + 1 if limit is not None else -1)
    if limit is not None and len(data) > limit:
        raise ValueError("question file too large")
    return data

def _text(value, name, maxlen):
    if not isinstance(value, str) or not value.strip() or len(value) > maxlen:
        raise ValueError("invalid " + name)
    return value

def _questions(raw):
    try:
        data = json.loads(raw.decode("utf-8"))
    except (UnicodeError, ValueError) as exc:
        raise ValueError("invalid questions JSON") from exc
    if not isinstance(data, dict) or set(data) != {"version", "questions"}:
        raise ValueError("invalid questions envelope")
    if type(data["version"]) is not int or data["version"] != 1:
        raise ValueError("unsupported questions version")
    questions = data["questions"]
    if not isinstance(questions, list) or not 1 <= len(questions) <= 50:
        raise ValueError("expected 1 to 50 questions")
    ids = set()
    for q in questions:
        if not isinstance(q, dict) or not {"id", "prompt"} <= set(q):
            raise ValueError("question id/prompt missing")
        if set(q) - {"id", "prompt", "choices", "artifactRefs"}:
            raise ValueError("unknown question fields")
        qid = _text(q["id"], "id", 64)
        if not ID_RE.fullmatch(qid) or qid in ids:
            raise ValueError("invalid or duplicate question id")
        ids.add(qid)
        _text(q["prompt"], "prompt", 1200)
        for field, limit, maxlen in (("choices", 12, 300), ("artifactRefs", 10, 250)):
            values = q.get(field, [])
            if not isinstance(values, list) or len(values) > limit:
                raise ValueError("invalid " + field)
            for v in values:
                _text(v, field, maxlen)
            if len(set(values)) != len(values):
                raise ValueError("duplicate " + field)
    return questions

CSS = """
<style>
.pg-feedback{padding:16px;border:2px solid #57606a;border-radius:8px;background:white;margin-bottom:22px}
.pg-feedback .warning{border:1px solid #bf8700;background:#fff8e6;padding:9px}
.pg-feedback .item{border:1px solid #d0d7de;border-radius:6px;padding:10px;margin:12px 0}
.pg-feedback label{display:block;font-weight:600;margin:7px 0 3px}
.pg-feedback select,.pg-feedback textarea{display:block;width:100%;padding:6px;font:inherit}
.pg-feedback textarea{min-height:64px}
.pg-feedback button{font:inherit;background:#0969da;color:white;border:none;padding:8px 12px;border-radius:6px}
.pg-feedback button:focus-visible{outline:3px solid #bf8700;outline-offset:2px}
.pg-feedback .refs{color:#57606a;overflow-wrap:anywhere}
@media print {.pg-feedback button{display:none}}
</style>
"""

JS = """
<script>
(() => {
  "use strict";
  const meta = __META__;
  const panel = document.getElementById("pg-plan-feedback");
  const message = panel.querySelector("[data-message]");
  panel.querySelector("[data-export]").addEventListener("click", () => {
    const answers = [];
    for (const item of panel.querySelectorAll("[data-question-id]")) {
      const questionId = item.getAttribute("data-question-id");
      const state = item.querySelector("[data-state]").value;
      const response = item.querySelector("[data-response]").value.trim();
      const note = item.querySelector("[data-note]").value.trim();
      if ((state === "answered" && !response) || (state !== "answered" && response) ||
          (state === "deferred" && !note) || (state === "unanswered" && note)) {
        message.textContent = questionId + ": 回答内容と状態が一致しません。";
        item.querySelector("[data-state]").focus();
        return;
      }
      answers.push({ questionId, status: state, response, note });
    }
    const feedback = {
      schemaVersion: 1,
      kind: "plan-review-feedback",
      taskId: meta.taskId,
      source: meta.source,
      feedback_only: true,
      approval_granted: false,
      generatedAt: new Date().toISOString(),
      answers
    };
    const blob = new Blob([JSON.stringify(feedback, null, 2) + "\\n"],
                          {type:"application/json;charset=utf-8"});
    const href = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = href;
    link.download = meta.taskId + "-review-feedback.json";
    link.click();
    requestAnimationFrame(() => URL.revokeObjectURL(href));
    message.textContent = "レビュー回答を保存しました。C-3 承認ではありません。";
  });
})();
</script>
"""

def render_review_questions(work_dir, task_id):
    """Render explicit questions only; never modify gate/plan/approval."""
    qpath = os.path.join(work_dir, "review-questions.json")
    if not os.path.lexists(qpath):
        return ""
    qbytes = _read(qpath, MAX_BYTES)
    questions = _questions(qbytes)
    plan = _read(os.path.join(work_dir, "plan.md"))
    meta = {
        "taskId": task_id,
        "source": {
            "plan": {"path": "plan.md", "sha256": hashlib.sha256(plan).hexdigest()},
            "questions": {"path": "review-questions.json", "sha256": hashlib.sha256(qbytes).hexdigest()},
        },
    }
    # Metadata embedded as JS data, never as executable user content.
    safe_meta = json.dumps(meta, ensure_ascii=True).replace("<", "\\u003c").replace(">", "\\u003e").replace("&", "\\u0026")
    out = [CSS,
           '<section id="pg-plan-feedback" class="pg-feedback" aria-labelledby="pg-feedback-heading">',
           '<h2 id="pg-feedback-heading">計画レビューへの回答</h2>',
           '<p class="warning">レビュー専用です。回答はC-3承認、実行許可、マージ許可ではありません。外部送信もしません。</p>']
    for q in questions:
        qid = html.escape(q["id"], quote=True)
        out += ['<div class="item" data-question-id="%s">' % qid,
                '<h3>%s — %s</h3>' % (html.escape(q["id"]), html.escape(q["prompt"]))]
        if q.get("artifactRefs"):
            out.append('<p class="refs">参照: %s</p>' % html.escape(", ".join(q["artifactRefs"])))
        out += ['<label for="pg-state-%s">回答状態</label>' % qid,
                '<select id="pg-state-%s" data-state>' % qid,
                '<option value="unanswered">未回答</option><option value="answered">回答済み</option>',
                '<option value="deferred">保留</option></select>',
                '<label for="pg-response-%s">回答 / 保留理由</label>' % qid]
        if q.get("choices"):
            out += ['<select id="pg-response-%s" data-response>' % qid,
                    '<option value="">選択してください</option>']
            for choice in q["choices"]:
                val = html.escape(choice, quote=True)
                out.append('<option value="%s">%s</option>' % (val, html.escape(choice)))
            out.append('</select>')
        else:
            out.append('<textarea id="pg-response-%s" data-response maxlength="4000"></textarea>' % qid)
        out += ['<label for="pg-note-%s">補足 / 保留理由</label>' % qid,
                '<textarea id="pg-note-%s" data-note maxlength="4000"></textarea>' % qid]
        out.append('</div>')
    out += ['<button type="button" data-export>回答JSONを保存</button>',
            '<p role="status" aria-live="polite" data-message></p></section>',
            JS.replace("__META__", safe_meta)]
    return "\n".join(out)
