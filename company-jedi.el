;;; company-jedi.el --- Jedi backend for company-mode

;; Copyright (C) 2013 by Malyshev Artem

;; Author: Malyshev Artem <proofit404@gmail.com>
;; URL: https://github.com/proofit404/company-jedi
;; Version: 0.0.1
;; Package-Requires: ((company "0.6.12"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;;; Code:

(require 'company)
(eval-when-compile (require 'cl))
(require 'url)
(require 'json)

(defvar company-jedi-host "localhost"
  "Target host with jedi server.")

(defvar company-jedi-port 24970
  "Port for start_jedi connection.")

(defvar company-jedi-command
  (concat (file-name-as-directory user-emacs-directory)
          "jedi/venv/bin/python3 -m start_jedi -p "
          (number-to-string company-jedi-port))
  "Command to run start_jedi server.")

(defvar company-jedi-dir
  (file-name-directory load-file-name)
  "Directory containing start_jedi package.")

(defvar company-jedi-process nil
  "Currently running start_jedi process.")

(defun company-jedi-running-p ()
  "Check for running start_jedi server."
  (and company-jedi-process
       (not (null (process-live-p company-jedi-process)))))

(defun company-jedi-bootstrap ()
  "Run company-jedi-command process."
  (let ((default-directory company-jedi-dir))
    (setq company-jedi-process
          (start-process-shell-command "start_jedi" nil company-jedi-command))))

;;;###autoload
(defun company-jedi-start ()
  "Start remote jedi server."
  (interactive)
  (unless (company-jedi-running-p)
    (company-jedi-bootstrap)))

(defun company-jedi-do-request (body)
  "Make POST Request to jedi server.

BODY mast be a encoded json string."
  (let ((url (format "http://%s:%s" company-jedi-host company-jedi-port))
        (url-request-method "POST")
        (url-request-extra-headers `(("Content-Type" . "application/json")))
        (url-request-data body))
    (with-current-buffer (url-retrieve-synchronously url)
      (case url-http-response-status
        (200 (progn
               (goto-char url-http-end-of-headers)
               (company-jedi-decode)))
        (500 (error (buffer-string)))))))

(defun company-jedi-point ()
  "Return json compatible buffer point description."
  (list (cons "source" (buffer-substring-no-properties (point-min) (point-max)))
                       (cons "line" (line-number-at-pos (point)))
                       (cons "column" (current-column))
                       (cons "path" (or (buffer-file-name) ""))))

(defun company-jedi-encode (arg)
  "Encode ARG to JSON."
  (let ((json-array-type 'list))
    (json-encode arg)))

(defun company-jedi-decode ()
  "Decode JSON at point."
  (let ((json-array-type 'list))
    (json-read)))

(defun company-jedi-decode-from-string (arg)
  "Decode JSON from ARG."
  (let ((json-array-type 'list))
    (json-read-from-string arg)))

(defun company-jedi-candidates-json ()
  "Generate json for candidates request."
  (company-jedi-encode
     (list (cons "command" "candidates")
           (cons "attributes" (company-jedi-point)))))

(defun company-jedi-candidates ()
  "Request completion candidates from jedi."
  (company-jedi-do-request (company-jedi-candidates-json)))

(defun company-jedi-location-json ()
  "Generate json for location request."
  (company-jedi-encode
     (list (cons "command" "location")
           (cons "attributes" (company-jedi-point)))))

(defun company-jedi-location ()
  "Request completion location from jedi."
  (company-jedi-do-request (company-jedi-location-request)))

;;;###autoload
(defun company-jedi (command &optional arg)
  "Jedi backend for company-mode.

See `company-backends' for more info about COMMAND and ARG."
  (interactive (list 'interactive))
  (case command
    (interactive (company-begin-backend 'company-jedi))
    (prefix (and (memq major-mode '(python-mode inferior-python-mode))
                 (company-jedi-running-p)
                 (company-grab-symbol)))
    (candidates (company-jedi-candidates))
    (location (company-jedi-location))))

(provide 'company-jedi)

;;; company-jedi.el ends here
