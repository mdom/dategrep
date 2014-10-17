(defun dategrep-narrow (format start end)
  (with-temp-buffer
    (call-process "dategrep" nil t nil "--format" format "--start" start "--end" end (buffer-file-name))
    (message "%s" (buffer-string))))
  (interactive "sFormat: \nsStart: \nsEnd: ")

(provide 'dategrep)
