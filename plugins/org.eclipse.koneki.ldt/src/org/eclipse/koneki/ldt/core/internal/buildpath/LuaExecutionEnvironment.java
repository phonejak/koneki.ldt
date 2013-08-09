/*******************************************************************************
 * Copyright (c) 2012 Sierra Wireless and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * Contributors:
 *     Sierra Wireless - initial API and implementation
 *******************************************************************************/
package org.eclipse.koneki.ldt.core.internal.buildpath;

import org.eclipse.core.runtime.IPath;

public class LuaExecutionEnvironment implements Comparable<LuaExecutionEnvironment> {

	private final String id;
	private final String version;
	private final IPath path;
	private final IPath template;
	private boolean embedded;
	private String[] templateBuildPathEntries;

	public LuaExecutionEnvironment(final String identifier, final String eeversion, final IPath pathToEE, String[] templateEntries) {
		id = identifier;
		version = eeversion;
		path = pathToEE;
		embedded = false;
		templateBuildPathEntries = templateEntries;

		// Create path to template
		IPath templatePath = null;
		if (pathToEE != null)
			templatePath = pathToEE.append(LuaExecutionEnvironmentConstants.EE_TEMPLATE_FOLDER);

		// Keep it if template file really exists
		if (templatePath != null && templatePath.toFile().exists())
			template = templatePath;
		else
			template = null;
	}

	protected void setEmbedded(final boolean embeddedEE) {
		this.embedded = embeddedEE;
	}

	public boolean isEmbedded() {
		return embedded;
	}

	public String getID() {
		return id;
	}

	public String getVersion() {
		return version;
	}

	public IPath getPath() {
		return path;
	}

	public IPath[] getSourcepath() {
		if (path != null && path.toFile().exists()) {
			final IPath sourcePath = path.append(LuaExecutionEnvironmentConstants.EE_FILE_API_ARCHIVE);
			if (sourcePath.toFile().exists()) {
				return new IPath[] { sourcePath };
			}
		}
		return new IPath[0];
	}

	public IPath[] getDocumentationPath() {
		if (path != null && path.toFile().exists()) {
			final IPath sourcePath = path.append(LuaExecutionEnvironmentConstants.EE_FILE_DOCS_FOLDER);
			if (sourcePath.toFile().exists()) {
				return new IPath[] { sourcePath };
			}
		}
		return new IPath[0];
	}

	public String getEEIdentifier() {
		return getID() + '-' + getVersion();
	}

	@Override
	public String toString() {
		return getEEIdentifier();
	}

	@Override
	public int hashCode() {
		final int prime = 31;
		int result = 1;
		result = prime * result + ((id == null) ? 0 : id.hashCode());
		result = prime * result + ((version == null) ? 0 : version.hashCode());
		return result;
	}

	@Override
	public boolean equals(final Object obj) {
		if (this == obj)
			return true;
		if (obj == null)
			return false;
		if (getClass() != obj.getClass())
			return false;
		final LuaExecutionEnvironment other = (LuaExecutionEnvironment) obj;
		if (id == null) {
			if (other.id != null)
				return false;
		} else if (!id.equals(other.id))
			return false;
		if (version == null) {
			if (other.version != null)
				return false;
		} else if (!version.equals(other.version))
			return false;
		return true;
	}

	@Override
	public int compareTo(final LuaExecutionEnvironment ee) {
		return getEEIdentifier().compareTo(ee.getEEIdentifier());
	}

	public IPath getTemplatePath() {
		return template;
	}

	public String[] getTemplateBuildPathEntries() {
		return templateBuildPathEntries;
	}

}
