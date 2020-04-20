ARG GDAL_VERSION=3.0.4
ARG PROJ_VERSION=6.3.1
ARG PYPROJ_VERSION=2.6.0
ARG INSTALL_PREFIX=/usr/local
ARG PYTHON_SHORT_VERSION=3.8

FROM vincejah/python-scientific:0.1 as builder

ARG INSTALL_PREFIX

ARG GDAL_VERSION
ARG GDAL_SOURCE_DIR=${INSTALL_PREFIX}/src/python-gdal

ARG PROJ_VERSION
ARG PROJ_SOURCE_DIR=${INSTALL_PREFIX}/src/proj
ARG PYPROJ_VERSION

# Install runtime dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        wget \
        automake libtool pkg-config libsqlite3-dev sqlite3 \
        libpq-dev \
        libcurl4-gnutls-dev \
        libproj-dev \
        libxml2-dev \
        libgeos-dev \
        libnetcdf-dev \
        libpoppler-dev \
        libspatialite-dev \
        libhdf4-alt-dev \
        libhdf5-serial-dev \
        libopenjp2-7-dev \
    && rm -rf /var/lib/apt/lists/*

# Build PROJ
RUN mkdir -p "${PROJ_SOURCE_DIR}" \
    && cd "${PROJ_SOURCE_DIR}" \
    && wget "http://download.osgeo.org/proj/proj-${PROJ_VERSION}.tar.gz" \
    && tar -xzf "proj-${PROJ_VERSION}.tar.gz" \
    && mv proj-${PROJ_VERSION} proj \
    && echo "#!/bin/sh" > proj/autogen.sh \
    && chmod +x proj/autogen.sh \
    && cd proj \
    && ./autogen.sh \
    && CXXFLAGS='-DPROJ_RENAME_SYMBOLS -O2' CFLAGS='-DPROJ_RENAME_SYMBOLS -O2' \
        ./configure --disable-static --prefix=${INSTALL_PREFIX} \
    && make -j"$(nproc)" \
    && make install DESTDIR="/build" \
    # Rename the library to libinternalproj
    && PROJ_SO=$(readlink /build${INSTALL_PREFIX}/lib/libproj.so | sed "s/libproj\.so\.//") \
    && PROJ_SO_FIRST=$(echo $PROJ_SO | awk 'BEGIN {FS="."} {print $1}') \
    && mv /build${INSTALL_PREFIX}/lib/libproj.so.${PROJ_SO} /build${INSTALL_PREFIX}/lib/libinternalproj.so.${PROJ_SO} \
    && ln -s libinternalproj.so.${PROJ_SO} /build${INSTALL_PREFIX}/lib/libinternalproj.so.${PROJ_SO_FIRST} \
    && ln -s libinternalproj.so.${PROJ_SO} /build${INSTALL_PREFIX}/lib/libinternalproj.so \
    && rm /build${INSTALL_PREFIX}/lib/libproj.*  \
    && ln -s libinternalproj.so.${PROJ_SO} /build${INSTALL_PREFIX}/lib/libproj.so.${PROJ_SO_FIRST} \
    && strip -s /build${INSTALL_PREFIX}/lib/libinternalproj.so.${PROJ_SO} \
    && for i in /build${INSTALL_PREFIX}/bin/*; do strip -s $i 2>/dev/null || /bin/true; done

# Build pyproj
RUN export PROJ_DIR=/build${INSTALL_PREFIX}/ \
    && export LD_LIBRARY_PATH=/build${INSTALL_PREFIX}/lib:$LD_LIBRARY_PATH \
    && pip install pyproj==${PYPROJ_VERSION} --no-binary pyproj

##################
# GDAL
##################
RUN mkdir -p "${GDAL_SOURCE_DIR}" \
    && cd "${GDAL_SOURCE_DIR}" \
    # Get latest GDAL source
    && wget "http://download.osgeo.org/gdal/${GDAL_VERSION}/gdal-${GDAL_VERSION}.tar.gz" \
    && tar -xvf "gdal-${GDAL_VERSION}.tar.gz" \
    # Compile and install GDAL
    && cd "gdal-${GDAL_VERSION}" \
    && export LD_LIBRARY_PATH=${INSTALL_PREFIX}/lib:$LD_LIBRARY_PATH \
    && ./configure --prefix=/usr --without-libtool \
            --with-hide-internal-symbols \
            --with-jpeg12 \
            --with-python \
            --with-webp --with-proj=/build${INSTALL_PREFIX} \
            --with-libtiff=internal --with-rename-internal-libtiff-symbols \
            --with-geotiff=internal --with-rename-internal-libgeotiff-symbols \
    && make -j"$(nproc)" \
    && make install DESTDIR="/build" \
    # Rename things
    && mkdir -p /build_gdal_python/usr/lib \
    && mkdir -p /build_gdal_python/usr/bin \
    && mkdir -p /build_gdal_version_changing/usr/include \
    && mv /build/usr/lib                    /build_gdal_version_changing/usr \
    && mv /build/usr/include/gdal_version.h /build_gdal_version_changing/usr/include \
    && mv /build/usr/bin/*.py               /build_gdal_python/usr/bin \
    && mv /build/usr/bin                    /build_gdal_version_changing/usr \
    && for i in /build_gdal_version_changing/usr/lib/*; do strip -s $i 2>/dev/null || /bin/true; done \
    && for i in /build_gdal_python/usr/lib/python3/dist-packages/osgeo/*.so; do strip -s $i 2>/dev/null || /bin/true; done \
    && for i in /build_gdal_version_changing/usr/bin/*; do strip -s $i 2>/dev/null || /bin/true; done

FROM vincejah/python-scientific:0.1 as final

ARG INSTALL_PREFIX
ARG PYTHON_SHORT_VERSION

#COPY --from=builder  /build${INSTALL_PREFIX}/share/proj/ ${INSTALL_PREFIX}/share/proj/
COPY --from=builder  /build${INSTALL_PREFIX}/include/ ${INSTALL_PREFIX}/include/
COPY --from=builder  /build${INSTALL_PREFIX}/bin/ ${INSTALL_PREFIX}/bin/
COPY --from=builder  /build${INSTALL_PREFIX}/lib/ ${INSTALL_PREFIX}/lib/

COPY --from=builder  /build/usr/share/gdal/ /usr/share/gdal/
COPY --from=builder  /build/usr/include/ /usr/include/
COPY --from=builder  /build_gdal_python/usr/ /usr/
COPY --from=builder  /build_gdal_version_changing/usr/ /usr/

COPY --from=builder /usr/local/lib/python${PYTHON_SHORT_VERSION}/site-packages/ /usr/local/lib/python${PYTHON_SHORT_VERSION}/site-packages/

RUN ldconfig
