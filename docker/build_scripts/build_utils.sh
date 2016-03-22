#!/bin/bash
# Helper utilities for build

PYTHON_DOWNLOAD_URL=https://www.python.org/ftp/python
OPENSSL_DOWNLOAD_URL=http://www.openssl.org/source
GET_PIP_URL=https://bootstrap.pypa.io/get-pip.py


function check_var {
    if [ -z "$1" ]; then
        echo "required variable not defined"
        exit 1
    fi
}


function lex_pyver {
    # Echoes Python version string padded with zeros
    # Thus:
    # 3.2.1 -> 003002001
    # 3     -> 003000000
    echo $1 | awk -F "." '{printf "%03d%03d%03d", $1, $2, $3}'
}


function do_python_build {
    local py_ver=$1
    check_var $py_ver
    local soabi_flags=$2
    check_var $soabi_flags
    mkdir -p /opt/python/${py_ver}${soabi_flags}/lib
    if [ $(lex_pyver $py_ver) -lt $(lex_pyver 3.3) ]; then
        if [ $soabi_flags = "mu" ]; then
            local unicode_flags="--enable-unicode=ucs4"
        else
            local unicode_flags="--enable-unicode=ucs2"
        fi
    fi
    # -Wformat added for https://bugs.python.org/issue17547 on Python 2.6
    CFLAGS="-Wformat" ./configure --prefix=/opt/python/${py_ver}${soabi_flags} --disable-shared $unicode_flags > /dev/null
    make -j2 > /dev/null
    make install > /dev/null
}


function build_python {
    local py_ver=$1
    check_var $py_ver
    local py_ver2="$(echo $py_ver | cut -d. -f 1,2)"
    check_var $PYTHON_DOWNLOAD_URL
    wget -q $PYTHON_DOWNLOAD_URL/$py_ver/Python-$py_ver.tgz
    if [ $(lex_pyver $py_ver) -lt $(lex_pyver 3.3) ]; then
        local soabi_flags_list="mu m"
    fi
    for soabi_flags in ${soabi_flags_list:-m}; do
        tar -xzf Python-$py_ver.tgz
        (cd Python-$py_ver && do_python_build $py_ver $soabi_flags)
        if [ $(lex_pyver $py_ver) -ge $(lex_pyver 3) ]; then \
            ln -s /opt/python/${py_ver}${soabi_flags}/bin/python3 /opt/python/${py_ver}${soabi_flags}/bin/python;
        fi;
        ln -s /opt/python/${py_ver}${soabi_flags}/ /opt/${py_ver2}${soabi_flags}
        /opt/python/${py_ver}${soabi_flags}/bin/python get-pip.py
        /opt/python/${py_ver}${soabi_flags}/bin/pip install wheel
        rm -rf Python-$py_ver
    done
    rm -f Python-$py_ver.tgz
}


function build_pythons {
    check_var $GET_PIP_URL
    curl -sLO $GET_PIP_URL
    for py_ver in $@; do
        build_python $py_ver
    done
    rm get-pip.py
}


function do_openssl_build {
    ./config no-ssl2 no-shared -fPIC --prefix=/usr/local/ssl > /dev/null
    make > /dev/null
    make install > /dev/null
}


function build_openssl {
    local openssl_fname=$1
    check_var $openssl_fname
    local openssl_sha256=$2
    check_var $openssl_sha256
    check_var $OPENSSL_DOWNLOAD_URL
    echo "${openssl_sha256}  ${openssl_fname}.tar.gz" > ${openssl_fname}.tar.gz.sha256
    curl -sLO $OPENSSL_DOWNLOAD_URL/${openssl_fname}.tar.gz
    sha256sum -c ${openssl_fname}.tar.gz.sha256
    tar -xzf ${openssl_fname}.tar.gz
    (cd ${openssl_fname} && do_openssl_build)
    rm -rf ${openssl_fname} ${openssl_fname}.tar.gz ${openssl_fname}.tar.gz.sha256
}