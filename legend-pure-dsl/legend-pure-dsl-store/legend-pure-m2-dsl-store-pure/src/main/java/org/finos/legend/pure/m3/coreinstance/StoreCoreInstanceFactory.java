package org.finos.legend.pure.m3.coreinstance;

import org.finos.legend.pure.m3.coreinstance.BaseM3CoreInstanceFactory;

public class StoreCoreInstanceFactory extends BaseM3CoreInstanceFactory
{
    @Override
    public boolean supports(String classifierPath)
    {
        return StoreCoreInstanceFactoryRegistry.REGISTRY.getFactoryForPath(classifierPath) != null;
    }

    @Override
    public org.finos.legend.pure.m4.coreinstance.CoreInstance createCoreInstance(String name, int internalSyntheticId, org.finos.legend.pure.m4.coreinstance.SourceInformation sourceInformation, org.finos.legend.pure.m4.coreinstance.CoreInstance classifier, org.finos.legend.pure.m4.ModelRepository repository, boolean persistent)
    {
        org.finos.legend.pure.m4.coreinstance.factory.CoreInstanceFactory factory = StoreCoreInstanceFactoryRegistry.REGISTRY.getFactoryForPath(getClassifierPath(classifier));
        if (factory != null)
        {
            return factory.createCoreInstance(name, internalSyntheticId, sourceInformation, classifier, repository, persistent);
        }
        throw new RuntimeException("Unsupported classifier: " + getClassifierPath(classifier));
    }
}
