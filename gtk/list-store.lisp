;;;; -*- Mode: lisp; indent-tabs-mode: nil -*-
;;;
;;; list-store.lisp -- GtkListStore object
;;;                 
;;;
;;; Copyright (C) 2007, Roman Klochkov <kalimehtar@mail.ru>
;;;
(declaim (optimize debug))
(in-package :gtk-cffi)

(defclass list-store (g-object tree-model)
  ())

(defcfun "gtk_list_store_newv" :pointer (columns :int) (gtypes :pointer))


(defmethod gconstructor ((list-store list-store)
                         &key columns values &allow-other-keys)
  "Make a list with columns of given types. Assign values to store if given.
NB! Should there be named columns?"
  (check-type columns list "a list of GType keywords")
  (check-type values list "a list of rows (lists)")
  (prog1
      (let ((n (length columns)))
        (with-foreign-object (arr :int n)
          (dotimes (i n)
            (setf (mem-aref arr :int i)
                  (keyword->g-type (nth i columns))))
          (gtk-list-store-newv n arr)))
    (mapc (lambda (row) (append-values list-store row)) values)))


(defcfun "gtk_list_store_append" :void 
  (store pobject) (iter (struct tree-iter :out t)))

(defun show-iter (prefix tree-iter)
  (format t "~a: ~a ~a ~a~%" prefix tree-iter (pointer tree-iter) 
          (when (slot-boundp tree-iter 'cffi-objects::value)
            (slot-value tree-iter 'cffi-objects::value))))
 

(defmethod append-iter ((list-store list-store) &optional
                        (tree-iter (tree-iter list-store)))
  (gtk-list-store-append list-store tree-iter))
;  (show-iter "appended" tree-iter))

(defcfun "gtk_list_store_set_value" :void (store pobject) 
         (iter (struct tree-iter)) (column :int) (g-value pobject))

(defmethod (setf model-values)
  (values (list-store list-store)
   &key (tree-iter (tree-iter list-store)) column 
        (columns (when column (list column))))
  "Example: (setf (model-values list-store :col 1) \"val1\")"
  (declare (type list columns values))
  (let ((%cols (append columns (loop :for i
                                     :from (length columns)
                                     :below (length values)
                                     :collecting i))))
    (mapcar
     (lambda (col val)
       (with-g-value (:value val :g-type (column-type list-store col))
         ;(show-iter "set" tree-iter)
;         (format t "set val: ~a type: ~a~%" val (column-type list-store col))
         (assert (/= (g-type *g-value*) 0))
         (gtk-list-store-set-value list-store
                                   tree-iter col *g-value*)
         (unless (/= (g-type *g-value*) 0) (cerror "Bad g-val" *g-value*))))
     %cols values)))

(defcfun "gtk_list_store_clear" :void (store pobject))

(defmethod clear ((list-store list-store))
  (gtk-list-store-clear list-store))

(defmethod append-values ((list-store list-store) values)
  (append-iter list-store)
  (setf (model-values list-store) values))
          
