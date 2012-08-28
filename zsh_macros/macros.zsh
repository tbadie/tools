# Copyright (c) 2012, Thomas Badie
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#    * Redistributions of source code must retain the above copyright
#      notice, this list of conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above copyright
#      notice, this list of conditions and the following disclaimer in the
#      documentation and/or other materials provided with the distribution.
#    * Neither the name of the <organization> nor the
#      names of its contributors may be used to endorse or promote products
#      derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THOMAS BADIE "AS IS" AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THOMAS BADIE OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
# BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

autoload -U add-zsh-hook

# Where we will copy the macros.
export ZMACROS_DIRECTORY=$HOME/zsh_macros

# The file that records all the macros in use.
export ZMACROS_MASTERFILE=/tmp/zmacros_master_file

# The variable to put in your PS1 in the aim to know whether we are
# recording a macro or not, and its number.
export ZMACROS_INFO=""

__zmacros-get-new-counter()
{
    local id=`awk 'BEGIN{ max=0; } { if ($2 > max) max = $2; }
                   END{ print max }' $ZMACROS_MASTERFILE 2> /dev/null || echo 0`

    echo $((id + 1))
}

# Manage master file
# The master file is formatted like this:
# <filename> <id>

# This function registers the file and associate it to an id.
__zmacros-register-file()
{
    local filename=$ZMACROS_TEMPFILE
    local id=`__zmacros-get-new-counter`

    ZMACROS_INFO="R$id"

    echo "$filename $id" >> $ZMACROS_MASTERFILE
}

# This function takes an id and returns the filename associated.
__zmacros-get-file()
{
    local id=$1

    if [ "$id" = 'a' ]
    then
        # 'a' is the indication that we want to use the last recorded
        # macro.  tail print the whole line, but we just want the
        # file, that's why we use awk too.
        if [ -f "$ZMACROS_MASTERFILE" ]
        then
            tail -1 $ZMACROS_MASTERFILE | awk '{print $1}'
        fi
    else

# More tricky that it seems.
# http://www.gnu.org/software/gawk/manual/html_node/Using-Shell-Variables.html
        echo `awk "/ $id/ "'{print $1 }' $ZMACROS_MASTERFILE`
    fi
}

# The function called by the hook.
__zmacros-add-to-file()
{
    if [ "$3" = "macro-end" ]
    then
        return
    fi

# Why $3:
# http://unix.derkeiler.com/Newsgroups/comp.unix.shell/2004-11/0732.html
    echo "$3" >> $ZMACROS_TEMPFILE
}

# Helpers
__zmacros-exec_file()
{
    $1
}

__zmacros-cp_file()
{
    local new_name;

    echo "Enter the name you want to give."
    read new_name;

    if [ ! -d "$ZMACROS_DIRECTORY" ]
    then
        echo "The directory doesn't exist. I will create " \
        "$ZMACROS_DIRECTORY. Is that okay ?[yn]"
        local answer
        read answer
        test $answer = "y" && mkdir $ZMACROS_DIRECTORY
        test $answer = "n" &&
          echo "Please set the variable ZMACROS_DIRECTORY" \
               "accordingly to your wish." \
               && return
    fi

    cp $1 $ZMACROS_DIRECTORY/$new_name
}

__zmacros-template-apply()
{
    local fn=$1
    local id=${2:-a}
    local file=`__zmacros-get-file $id`

    # Can seems weird, but 'test' implements 'and' in a non-intuitive
    # way since we make the second test, even if the first is false.
    if [ -n "$file" -a -f "$ZMACROS_MASTERFILE" ]
    then
        if [ 0 -ne $(wc -l "$ZMACROS_MASTERFILE" | awk '{ print $1 }') ]
        then
            $fn $file
        else
            echo "No macro recorded." 1>&2
        fi
    else
        echo "No macro recorded." 1>&2
    fi
}



# Interface of the module
macro-record()
{
    add-zsh-hook preexec __zmacros-add-to-file

    export ZMACROS_TEMPFILE=$(mktemp)
    __zmacros-register-file

    zle reset-prompt

    echo "#! /usr/bin/zsh" > $ZMACROS_TEMPFILE
}

macro-end()
{
    chmod +x $ZMACROS_TEMPFILE
    add-zsh-hook -d preexec __zmacros-add-to-file
    ZMACROS_INFO=""
    zle reset-prompt
}

macro-execute()
{
    __zmacros-template-apply __zmacros-exec_file $1
}

macro-name()
{
    __zmacros-template-apply __zmacros-cp_file $1
}

macro-remove-all()
{
    cat $ZMACROS_MASTERFILE | awk '{ print $1 }' | xargs rm -f
    echo "" > $ZMACROS_MASTERFILE
}


# Declare these functions as widgets, so we can bind them easily.
zle -N macro-record
zle -N macro-end

# Bind to the Emacs binding.
if [ "undefined-key" =  "$(bindkey '^X(' | awk '{print $2}')" -a \
    "undefined-key" = "$(bindkey '^X)'  | awk '{print $2}')" ]
then
    bindkey '^X(' macro-record                      # ctrl-x (
    bindkey '^X)' macro-end                         # ctrl-x )
else
    echo "Warning: Bindings for macro-{record,end} already used." 1>&2
fi

# User should alias macro-execute...
if [ -z "$(alias e)" ]
then
    alias e=macro-execute
fi

# This function is aimed to be added in your RPROMPT. That prints
# "<R${macro_id}>" in color. It is printed one command after the
# beginning of the recording, and finish one command after the end.
zmacros_info_wrapper()
{
    if [ -n "${ZMACROS_INFO}" ]
    then
        echo "%{$fg[grey]%}%F{5}<%F{2}${ZMACROS_INFO}%F{5}>%f%{$reset_color%}$del"
    fi
}

# To add it, you should set the prompt_subst option. Then, paste the
# following line:
# RPROMT='$(zmacros_info_wrapper)'

# Note that the single quote is *mandatory*. It allows the function to
# be called before each new prompt. This behavior is due to the
# prompt_subst option.
