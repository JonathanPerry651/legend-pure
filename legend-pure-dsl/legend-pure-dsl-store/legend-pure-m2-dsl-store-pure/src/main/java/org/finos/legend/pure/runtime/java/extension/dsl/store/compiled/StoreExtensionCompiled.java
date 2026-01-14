package org.finos.legend.pure.runtime.java.extension.dsl.store.compiled;

import org.eclipse.collections.api.set.SetIterable;
import org.eclipse.collections.impl.factory.Sets;
import org.finos.legend.pure.m3.coreinstance.RuntimeCoreInstanceFactoryRegistry;
import org.finos.legend.pure.m3.coreinstance.StoreCoreInstanceFactoryRegistry;
import org.finos.legend.pure.runtime.java.compiled.extension.CompiledExtension;

/**
 * This class exists to resolve a circular dependency between the generator and the generated code in Bazel.
 *
 * <p>1. Maven's "Plugin Classpath" Magic: In Maven, the code generator runs as a plugin configured with
 * dependencies (like {@code legend-pure-runtime-java-extension-compiled-dsl-store}). Maven downloads
 * those jars and puts them on the generator's classpath, allowing {@code ServiceLoader} to discover
 * {@code M3StoreExtensionCompiled} from the *already built* artifact.
 *
 * <p>2. Bazel's Explicit Graph: In Bazel, we build the generator from scratch.
 * To build the Final Library, we need Generated Sources.
 * To generate sources, we need the Generator.
 * The Generator needs to know that Store/Runtime are "Platform Classes" (M3 types).
 * If the Generator depends on the Final Library to get that info, we create a cycle:
 * Final Library -> Generated Sources -> Generator -> Final Library.
 *
 * <p>3. The Fix: This "bootstrap" extension in the lower-level module provides *just* the M3 type
 * information needed by the generator. It allows the generator to run *before* the final library is built,
 * breaking the cycle and manually untangling what Maven handles via pre-built artifacts.
 */
public class StoreExtensionCompiled implements CompiledExtension
{


    @Override
    public SetIterable<String> getExtraCorePath()
    {
        return Sets.mutable.withAll(RuntimeCoreInstanceFactoryRegistry.ALL_PATHS)
                .withAll(StoreCoreInstanceFactoryRegistry.ALL_PATHS);
    }

    @Override
    public String getRelatedRepository()
    {
        return "platform_dsl_store";
    }

    public static CompiledExtension extension()
    {
        return new StoreExtensionCompiled();
    }
}
