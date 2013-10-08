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
package org.eclipse.koneki.ldt.core;

import org.eclipse.core.runtime.CoreException;
import org.eclipse.core.runtime.IPath;
import org.eclipse.core.runtime.IProgressMonitor;
import org.eclipse.dltk.core.IScriptFolder;
import org.eclipse.dltk.core.ISourceModule;

/**
 * @since 1.0
 */
@SuppressWarnings("deprecation")
public abstract class IProjectSourceVisitor2 implements IProjectSourceVisitor {

	@Override
	public void processFile(IPath absolutePath, IPath relativePath, String charset, IProgressMonitor monitor) throws CoreException {
		// nothing to do
	}

	@Override
	public void processDirectory(IPath absolutePath, IPath relativePath, IProgressMonitor monitor) throws CoreException {
		// nothing to do
	}

	public abstract void processFile(final ISourceModule sourceModule, final IProgressMonitor monitor) throws CoreException;

	public abstract void processDirectory(final IScriptFolder sourceModule, final IProgressMonitor monitor) throws CoreException;

}
