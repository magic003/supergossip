# Copyright (c) 2010 Minjie Zha
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require 'yaml'

class Class
    def transients
        @transients = [] if !@transients
        @transients
    end

    def transients= t
        @transients = t if t.kind_of?(Array)
    end

    def transient_with_parent
        t = []
        clazz = self
        while clazz
            t.concat(clazz.transients)
            clazz = clazz.superclass
        end
        t.uniq
    end
end

class Object 
    def self.transient *var
        for i in (0..var.length-1)
            var[i] = '@' + var[i].to_s
        end
        self.transients.concat(var)
        self.transients.uniq!
    end

    def to_yaml_properties
        t = self.class.transient_with_parent
        instance_variables.delete_if {|a| t.include?(a.to_s) }
    end
end
