; -*- mode: lisp; package: pcl; encoding: shift_jis -*-

;;;
;;; *************************************************************************
;;; Copyright (c) 1985, 1986, 1987, 1988, 1989, 1990 Xerox Corporation.
;;; All rights reserved.
;;;
;;; Use and copying of this software and preparation of derivative works
;;; based upon this software are permitted.  Any distribution of this
;;; software or derivative works must comply with all applicable United
;;; States export control laws.
;;;
;;; This software is made available AS IS, and Xerox Corporation makes no
;;; warranty about the software, its performance or its conformity to any
;;; specification.
;;;
;;; Any person obtaining a copy of this software is requested to send their
;;; name and post office or electronic mail address to:
;;;   CommonLoops Coordinator
;;;   Xerox PARC
;;;   3333 Coyote Hill Rd.
;;;   Palo Alto, CA 94304
;;; (or send Arpanet mail to CommonLoops-Coordinator.pa@Xerox.arpa)
;;;
;;; Suggestions, comments and requests for improvements are also welcome.
;;; *************************************************************************
;;;

(eval-when (:compile-toplevel :load-toplevel :execute)
  (require "xl-pcl/pkg")
  (require "xl-pcl/boot")
  (require "xl-pcl/defs")
  (require "xl-pcl/low")
  (require "xl-pcl/fin")
  )

(in-package :pcl)

(fix-early-generic-functions)
(compute-standard-slot-locations)
(setq *boot-state* 'complete)

#+Lispm
(eval-when (load eval)
  (si:record-source-file-name 'print-std-instance 'defun 't))

(defun print-std-instance (instance stream depth)
  (declare (ignore depth))
  (print-object instance stream))


(provide "xl-pcl/fixup")
