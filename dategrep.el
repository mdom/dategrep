(defun dategrep-narrow (format start end)
  (interactive "sFormar: \nsStart: \nsEnd: ")
  (with-temp-buffer
    (call-process "dategrep" nil t nil "--format" format "--start" start "--end" end (buffer-file-name))
    (message "%s" (buffer-string))))

(provide 'dategrep)
