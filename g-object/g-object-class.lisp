;;;; -*- Mode: lisp; indent-tabs-mode: nil -*-
;;;
;;; g-object-class.lisp --- G-ObjectClass wrappers for Common Lisp
;;;
;;; Copyright (C) 2007, Roman Klochkov <kalimehtar@mail.ru>
;;;

(in-package #:g-object-cffi)

(defclass g-object-class (object)
  ((free-after :initform nil)))

(defcstruct* g-object-class-struct
  (type-class g-type-class) ; :struct
  (construct-properties :pointer)
  (constructor :pointer)
  (set-property :pointer)
  (get-property :pointer)
  (dispose :pointer)
  (finalize :pointer)
  (dispatch-properties-changed :pointer)
  (notify :pointer)
  (constructed :pointer)
  (pdummy :pointer :count 7))

(defmethod gconstructor ((g-object-class g-object-class) &key object)
  (mem-ref (pointer object) :pointer))

(defcfun "g_object_class_list_properties"
    (garray (object g-param-spec)) (obj-class pobject) (n-props :pointer))

(defclass g-param-spec (object)
  ())

(defmethod list-properties ((g-object-class g-object-class))
  (g-object-class-list-properties g-object-class *array-length*))

(defcfun "g_object_class_find_property" :pointer
  (obj-class pobject) (key :string))

(defmethod find-property ((g-object-class g-object-class) key)
  (let ((ptr (g-object-class-find-property g-object-class key)))
    (unless (null-pointer-p ptr)
      (make-instance 'g-param-spec :pointer ptr))))

(defcfun "g_param_spec_get_name" :string (param pobject))

(defmethod name ((g-param-spec g-param-spec))
  (g-param-spec-get-name g-param-spec))

(defcfun "g_param_spec_get_nick" :string (param pobject))

(defmethod nick ((g-param-spec g-param-spec))
  (g-param-spec-get-nick g-param-spec))

(defcfun "g_param_spec_get_blurb" :string (param pobject))

(defmethod blurb ((g-param-spec g-param-spec))
  (g-param-spec-get-blurb g-param-spec))

(defbitfield g-param-flags
    :readable :writable :construct :construct-only :lax-validation
    :static-name :static-nick :static-blurb)

(defcstruct* g-param-spec-struct
  "GParamSpec"
  (g-type-instance :pointer)
  (name :string)
  (flags g-param-flags)
  (g-param-spec-type :ulong)
  (owner-type :ulong))

(defmethod flags ((g-param-spec g-param-spec))
  (flags (make-instance 'g-param-spec-struct :pointer (pointer g-param-spec))))

(defmethod g-type ((g-param-spec g-param-spec) &key owner)
  (let ((struct (make-instance 'g-param-spec-struct 
                               :pointer (pointer g-param-spec))))
    (if owner 
        (owner-type struct)
        (g-param-spec-type struct))))

(defun show-properties (g-object)
  (let ((gclass (make-instance 'g-object-class :object g-object)))
    (map nil
         (lambda (param)
           (format t "~A~% nick=~A~% blurb=~A~% type=~A
 owner-type=~A~% flags=~A~%~%"
                   (name param) (nick param) (blurb param)
                   (g-type->lisp (g-type param))
                   (g-type->lisp (g-type param :owner t)) (flags param)))
         (list-properties gclass))))