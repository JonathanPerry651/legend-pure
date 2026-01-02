// Copyright 2020 Goldman Sachs
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package org.finos.legend.pure.m3.tests;

import org.finos.legend.pure.m4.coreinstance.SourceInformation;
import org.finos.legend.pure.m4.exception.PureException;
import org.junit.Assert;

import java.util.regex.Pattern;

public class PureAssertions
{
    // assertOriginatingPureException variants

    public static void assertOriginatingPureException(String expectedInfo, Exception exception)
    {
        assertOriginatingPureException(expectedInfo, null, null, exception);
    }

    public static void assertOriginatingPureException(Pattern expectedInfo, Exception exception)
    {
        assertOriginatingPureException(expectedInfo, null, null, exception);
    }

    public static void assertOriginatingPureException(String expectedInfo, Integer expectedLine, Integer expectedColumn, Exception exception)
    {
        assertOriginatingPureException(null, expectedInfo, null, expectedLine, expectedColumn, null, null, exception);
    }

    public static void assertOriginatingPureException(Pattern expectedInfo, Integer expectedLine, Integer expectedColumn, Exception exception)
    {
        assertOriginatingPureException(null, expectedInfo, null, expectedLine, expectedColumn, null, null, exception);
    }

    public static void assertOriginatingPureException(Class<? extends PureException> expectedClass, String expectedInfo, Exception exception)
    {
        assertOriginatingPureException(expectedClass, expectedInfo, null, null, exception);
    }

    public static void assertOriginatingPureException(Class<? extends PureException> expectedClass, Pattern expectedInfo, Exception exception)
    {
        assertOriginatingPureException(expectedClass, expectedInfo, null, null, exception);
    }

    public static void assertOriginatingPureException(Class<? extends PureException> expectedClass, String expectedInfo, Integer expectedLine, Integer expectedColumn, Exception exception)
    {
        assertOriginatingPureException(expectedClass, expectedInfo, null, expectedLine, expectedColumn, null, null, exception);
    }

    public static void assertOriginatingPureException(Class<? extends PureException> expectedClass, Pattern expectedInfo, Integer expectedLine, Integer expectedColumn, Exception exception)
    {
        assertOriginatingPureException(expectedClass, expectedInfo, null, expectedLine, expectedColumn, null, null, exception);
    }

    public static void assertOriginatingPureException(Class<? extends PureException> expectedClass, String expectedInfo, String expectedSource, Integer expectedLine, Integer expectedColumn, Exception exception)
    {
        assertOriginatingPureException(expectedClass, expectedInfo, expectedSource, expectedLine, expectedColumn, null, null, exception);
    }

    public static void assertOriginatingPureException(Class<? extends PureException> expectedClass, Pattern expectedInfo, String expectedSource, Integer expectedLine, Integer expectedColumn, Exception exception)
    {
        assertOriginatingPureException(expectedClass, expectedInfo, expectedSource, expectedLine, expectedColumn, null, null, exception);
    }

    public static void assertOriginatingPureException(Class<? extends PureException> expectedClass, String expectedInfo, String expectedSource, Integer expectedLine, Integer expectedColumn, Integer expectedEndLine, Integer expectedEndColumn, Exception exception)
    {
        PureException pe = PureException.findPureException(exception);
        Assert.assertNotNull("No Pure exception", pe);
        assertOriginatingPureException(expectedClass, expectedInfo, expectedSource, expectedLine, expectedColumn, expectedEndLine, expectedEndColumn, pe);
    }

    public static void assertOriginatingPureException(Class<? extends PureException> expectedClass, Pattern expectedInfo, String expectedSource, Integer expectedLine, Integer expectedColumn, Integer expectedEndLine, Integer expectedEndColumn, Exception exception)
    {
        PureException pe = PureException.findPureException(exception);
        Assert.assertNotNull("No Pure exception", pe);
        assertOriginatingPureException(expectedClass, expectedInfo, expectedSource, expectedLine, expectedColumn, expectedEndLine, expectedEndColumn, pe);
    }

    public static void assertOriginatingPureException(Class<? extends PureException> expectedClass, String expectedInfo, String expectedSource, Integer expectedLine, Integer expectedColumn, Integer expectedEndLine, Integer expectedEndColumn, PureException exception)
    {
        assertPureException(expectedClass, expectedInfo, expectedSource, expectedLine, expectedColumn, expectedEndLine, expectedEndColumn, exception.getOriginatingPureException());
    }

    public static void assertOriginatingPureException(Class<? extends PureException> expectedClass, Pattern expectedInfo, String expectedSource, Integer expectedLine, Integer expectedColumn, Integer expectedEndLine, Integer expectedEndColumn, PureException exception)
    {
        assertPureException(expectedClass, expectedInfo, expectedSource, expectedLine, expectedColumn, expectedEndLine, expectedEndColumn, exception.getOriginatingPureException());
    }

    // assertPureException variants

    public static void assertPureException(String expectedInfo, Exception exception)
    {
        assertPureException(null, expectedInfo, null, null, null, null, null, exception);
    }

    public static void assertPureException(Pattern expectedInfo, Exception exception)
    {
        assertPureException(null, expectedInfo, null, null, null, null, null, exception);
    }

    public static void assertPureException(String expectedInfo, Integer expectedLine, Integer expectedColumn, Exception exception)
    {
        assertPureException(null, expectedInfo, null, expectedLine, expectedColumn, null, null, exception);
    }

    public static void assertPureException(Pattern expectedInfo, Integer expectedLine, Integer expectedColumn, Exception exception)
    {
        assertPureException(null, expectedInfo, null, expectedLine, expectedColumn, null, null, exception);
    }

    public static void assertPureException(Class<? extends PureException> expectedClass, String expectedInfo, Exception exception)
    {
        assertPureException(expectedClass, expectedInfo, null, null, null, null, null, exception);
    }

    public static void assertPureException(Class<? extends PureException> expectedClass, Pattern expectedInfo, Exception exception)
    {
        assertPureException(expectedClass, expectedInfo, null, null, null, null, null, exception);
    }

    public static void assertPureException(Class<? extends PureException> expectedClass, String expectedInfo, String expectedSource, Exception exception)
    {
        assertPureException(expectedClass, expectedInfo, expectedSource, null, null, null, null, exception);
    }

    public static void assertPureException(Class<? extends PureException> expectedClass, Pattern expectedInfo, String expectedSource, Exception exception)
    {
        assertPureException(expectedClass, expectedInfo, expectedSource, null, null, null, null, exception);
    }

    public static void assertPureException(Class<? extends PureException> expectedClass, String expectedInfo, Integer expectedLine, Integer expectedColumn, Exception exception)
    {
        assertPureException(expectedClass, expectedInfo, null, expectedLine, expectedColumn, null, null, exception);
    }

    public static void assertPureException(Class<? extends PureException> expectedClass, Pattern expectedInfo, Integer expectedLine, Integer expectedColumn, Exception exception)
    {
        assertPureException(expectedClass, expectedInfo, null, expectedLine, expectedColumn, null, null, exception);
    }

    public static void assertPureException(Class<? extends PureException> expectedClass, String expectedInfo, String expectedSource, Integer expectedLine, Integer expectedColumn, Exception exception)
    {
        assertPureException(expectedClass, expectedInfo, expectedSource, expectedLine, expectedColumn, null, null, exception);
    }

    public static void assertPureException(Class<? extends PureException> expectedClass, Pattern expectedInfo, String expectedSource, Integer expectedLine, Integer expectedColumn, Exception exception)
    {
        assertPureException(expectedClass, expectedInfo, expectedSource, expectedLine, expectedColumn, null, null, exception);
    }

    public static void assertPureException(Class<? extends PureException> expectedClass, String expectedInfo, String expectedSource, Integer expectedLine, Integer expectedColumn, Integer expectedEndLine, Integer expectedEndColumn, Exception exception)
    {
        PureException pe = PureException.findPureException(exception);
        Assert.assertNotNull("No Pure exception", pe);
        assertPureException(expectedClass, expectedInfo, expectedSource, expectedLine, expectedColumn, expectedEndLine, expectedEndColumn, pe);
    }

    public static void assertPureException(Class<? extends PureException> expectedClass, Pattern expectedInfo, String expectedSource, Integer expectedLine, Integer expectedColumn, Integer expectedEndLine, Integer expectedEndColumn, Exception exception)
    {
        PureException pe = PureException.findPureException(exception);
        Assert.assertNotNull("No Pure exception", pe);
        assertPureException(expectedClass, expectedInfo, expectedSource, expectedLine, expectedColumn, expectedEndLine, expectedEndColumn, pe);
    }

    public static void assertPureException(Class<? extends PureException> expectedClass, String expectedInfo, String expectedSource, Integer expectedStartLine, Integer expectedStartColumn, Integer expectedLine, Integer expectedColumn, Integer expectedEndLine, Integer expectedEndColumn, Exception exception)
    {
        PureException pe = PureException.findPureException(exception);
        Assert.assertNotNull("No Pure exception", pe);
        assertPureException(expectedClass, expectedInfo, expectedSource, expectedStartLine, expectedStartColumn, expectedLine, expectedColumn, expectedEndLine, expectedEndColumn, pe);
    }

    public static void assertPureException(Class<? extends PureException> expectedClass, Pattern expectedInfo, String expectedSource, Integer expectedStartLine, Integer expectedStartColumn, Integer expectedLine, Integer expectedColumn, Integer expectedEndLine, Integer expectedEndColumn, Exception exception)
    {
        PureException pe = PureException.findPureException(exception);
        Assert.assertNotNull("No Pure exception", pe);
        assertPureException(expectedClass, expectedInfo, expectedSource, expectedStartLine, expectedStartColumn, expectedLine, expectedColumn, expectedEndLine, expectedEndColumn, pe);
    }

    public static void assertPureException(Class<? extends PureException> expectedClass, String expectedInfo, String expectedSource, Integer expectedLine, Integer expectedColumn, Integer expectedEndLine, Integer expectedEndColumn, PureException exception)
    {
        assertPureException(expectedClass, expectedInfo, expectedSource, null, null, expectedLine, expectedColumn, expectedEndLine, expectedEndColumn, exception);
    }

    public static void assertPureException(Class<? extends PureException> expectedClass, Pattern expectedInfo, String expectedSource, Integer expectedLine, Integer expectedColumn, Integer expectedEndLine, Integer expectedEndColumn, PureException exception)
    {
        assertPureException(expectedClass, expectedInfo, expectedSource, null, null, expectedLine, expectedColumn, expectedEndLine, expectedEndColumn, exception);
    }

    public static void assertPureException(Class<? extends PureException> expectedClass, String expectedInfo, String expectedSource, Integer expectedStartLine, Integer expectedStartColumn, Integer expectedLine, Integer expectedColumn, Integer expectedEndLine, Integer expectedEndColumn, PureException exception)
    {
        // Check class
        if (expectedClass != null)
        {
            Assert.assertTrue("Expected an exception of type " + expectedClass.getCanonicalName() + ", got: " + exception.getClass().getCanonicalName() + " message:" + exception.getMessage(),
                    expectedClass.isInstance(exception));
        }

        // Check info
        if (expectedInfo != null)
        {
            Assert.assertEquals(expectedInfo, exception.getInfo());
        }

        // Check source information
        assertSourceInformation(expectedSource, expectedStartLine, expectedStartColumn, expectedLine, expectedColumn, expectedEndLine, expectedEndColumn, exception.getSourceInformation());
    }

    public static void assertPureException(Class<? extends PureException> expectedClass, Pattern expectedInfo, String expectedSource, Integer expectedStartLine, Integer expectedStartColumn, Integer expectedLine, Integer expectedColumn, Integer expectedEndLine, Integer expectedEndColumn, PureException exception)
    {
        // Check class
        if (expectedClass != null)
        {
            Assert.assertTrue("Expected an exception of type " + expectedClass.getCanonicalName() + ", got: " + exception.getClass().getCanonicalName(),
                    expectedClass.isInstance(exception));
        }

        // Check info
        if ((expectedInfo != null) && !expectedInfo.matcher(exception.getInfo()).matches())
        {
            Assert.fail("Expected exception info matching:\n\t" + expectedInfo.pattern() + "\ngot:\n\t" + exception.getInfo());
        }

        // Check source information
        assertSourceInformation(expectedSource, expectedStartLine, expectedStartColumn, expectedLine, expectedColumn, expectedEndLine, expectedEndColumn, exception.getSourceInformation());
    }

    public static void assertSourceInformation(String expectedSource, Integer expectedStartLine, Integer expectedStartColumn, Integer expectedLine, Integer expectedColumn, Integer expectedEndLine, Integer expectedEndColumn, SourceInformation sourceInfo)
    {
        if (expectedSource != null)
        {
            Assert.assertEquals("Wrong source", expectedSource, sourceInfo.getSourceId());
        }
        if (expectedStartLine != null)
        {
            Assert.assertEquals("Wrong start line", expectedStartLine.intValue(), sourceInfo.getStartLine());
        }
        if (expectedStartColumn != null)
        {
            Assert.assertEquals("Wrong start column", expectedStartColumn.intValue(), sourceInfo.getStartColumn());
        }
        if (expectedLine != null)
        {
            Assert.assertEquals("Wrong line", expectedLine.intValue(), sourceInfo.getLine());
        }
        if (expectedColumn != null)
        {
            Assert.assertEquals("Wrong column", expectedColumn.intValue(), sourceInfo.getColumn());
        }
        if (expectedEndLine != null)
        {
            Assert.assertEquals("Wrong end line", expectedEndLine.intValue(), sourceInfo.getEndLine());
        }
        if (expectedEndColumn != null)
        {
            Assert.assertEquals("Wrong end column", expectedEndColumn.intValue(), sourceInfo.getEndColumn());
        }
    }
}
