(defun dategrep-narrow (format start end)
  (interactive "sFormat: \nsStart: \nsEnd: ")
  (let* ((file (buffer-file-name))
         (offsets
	  (with-temp-buffer
	    (call-process "dategrep" nil t nil "--byte-offsets" "--format" format "--start" start "--end" end file)
	    (mapcar 'string-to-number (split-string (buffer-string))))))   
    (narrow-to-region
     (byte-to-position (1+ (car  offsets)))
     (byte-to-position (1+ (cadr offsets))))))

(provide 'dategrep)
